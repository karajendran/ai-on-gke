import sys
import logging
import jsonpickle
import os
import pandas as pd
import ray
import re
import spacy
import time
import urllib.error
import urllib.request

from google.cloud import storage
from typing import List

IMAGE_BUCKET = os.environ['PROCESSING_BUCKET']
RAY_CLUSTER_HOST = os.environ['RAY_CLUSTER_HOST']
GCS_IMAGE_FOLDER = 'flipkart_images'


logging.config.fileConfig('/app/logging.conf')
logger = logging.getLogger(__name__)

@ray.remote(num_cpus=1)
def get_clean_df(df, logger, worker_process_node_id):

    # extract image urls
    def extract_url(image_list: str) -> List[str]:
        return image_list.replace('[', '').replace(']', '').replace('"', '').split(',')

    #download the image from public url to GCS
    def download_image(image_url, image_file_name, destination_blob_name):
        storage_client = storage.Client()
        try:
            logger.debug(f"image: {image_url}")
            urllib.request.urlretrieve(image_url, image_file_name)
            bucket = storage_client.bucket(IMAGE_BUCKET)
            blob = bucket.blob(destination_blob_name)
            blob.upload_from_filename(image_file_name)
            logger.debug(f"worker_process_node_id:{worker_process_node_id} File {image_file_name} uploaded to {destination_blob_name}")
            return True
        except urllib.error.HTTPError as err:
            if err.code == 404:
                logger.warning(f"worker_process_node_id:{worker_process_node_id} Image '{image_url}' not found")
            elif err.code == 504:
                logger.warning(f"worker_process_node_id:{worker_process_node_id} Image '{image_url}' timed out")
            else:
                logger.error(f"worker_process_node_id:{worker_process_node_id} Unhandled HTTPError exception")
        except urllib.error.URLError:
            logger.error(f"worker_process_node_id:{worker_process_node_id} URLError exception")
        except:
            logger.error(f"worker_process_node_id:{worker_process_node_id} Unhandled exception")
        return False

    # Cleaning the description text
    def prep_product_desc(df):

        spacy.cli.download("en_core_web_sm")
        logger.debug("en_core_web_sm downloaded")
        model = spacy.load("en_core_web_sm")
        logger.debug("en_core_web_sm loaded")
        def parse_nlp_description(description) -> str:
            if not pd.isna(description):
                try:
                    doc = model(description.lower())
                    lemmas = []
                    for token in doc:
                        if token.lemma_ not in lemmas and not token.is_stop and token.is_alpha:
                            lemmas.append(token.lemma_)
                    return ' '.join(lemmas)
                except:
                    logger.debug("Unable to load spacy model")

        df['description'] = df['description'].apply(parse_nlp_description)
        return df

    # Extract product attributes as key-value pair
    def parse_attributes(specification: str):
        spec_match_one = re.compile("(.*?)\\[(.*)\\](.*)")
        spec_match_two = re.compile("(.*?)=>\"(.*?)\"(.*?)=>\"(.*?)\"(.*)")
        if pd.isna(specification):
            return None
        m = spec_match_one.match(specification)
        out = {}
        if m is not None and m.group(2) is not None:
            phrase = ''
            for c in m.group(2):
                if c == '}':
                    m2 = spec_match_two.match(phrase)
                    if m2 and m2.group(2) is not None and m2.group(4) is not None:
                        out[m2.group(2)] = m2.group(4)
                    phrase = ''
                else:
                    phrase += c
        json_string = jsonpickle.encode(out)
        return json_string

    def get_product_image(df):
        products_with_no_image_count = 0
        products_with_no_image = []
        gcs_image_url = []

        temporary_image_directory = 'tmp-images'
        if not os.path.exists(temporary_image_directory):
            os.makedirs(temporary_image_directory)

        image_found_flag = False
        for id, image_list in zip(df['uniq_id'], df['image']):

            if pd.isnull(image_list):  # No image url
                logger.debug(f"WARNING: No image url: product {id}")
                products_with_no_image_count += 1
                products_with_no_image.append(id)
                gcs_image_url.append(None)
                continue
            image_urls = extract_url(image_list)
            for index in range(len(image_urls)):
                image_url = image_urls[index]
                image_file_name = f"{temporary_image_directory}/{id}_{index}.jpg"
                destination_blob_name = f"{GCS_IMAGE_FOLDER}/{id}_{index}.jpg"
                image_found_flag = download_image(
                    image_url, image_file_name, destination_blob_name)
                if image_found_flag:
                    gcs_image_url.append(
                        'gs://' + IMAGE_BUCKET + '/' + destination_blob_name)
                    break
            if not image_found_flag:
                logger.debug(f"WARNING: No image: product {id}")
                products_with_no_image_count += 1
                products_with_no_image.append(id)
                gcs_image_url.append(None)

        # appending gcs image uri into dataframe
        gcs_image_loc = pd.DataFrame(gcs_image_url, index=df.index)
        gcs_image_loc.columns = ["image_uri"]
        df_with_gcs_image_uri = pd.concat([df, gcs_image_loc], axis=1)
        return df_with_gcs_image_urai   

    df_with_gcs_image_uri = get_product_image(df)
    df_with_desc = prep_product_desc(df_with_gcs_image_uri)
    df_with_desc['attributes'] = df_with_desc['product_specifications'].apply(
        parse_attributes)

    return df_with_desc


def split_dataframe(df, chunk_size=199):
    chunks = list()
    num_chunks = len(df) // chunk_size + 1
    for i in range(num_chunks):
        chunks.append(df[i * chunk_size:(i + 1) * chunk_size])
    return chunks


# This function invokes ray task
def run_remote():

    #Read raw dataset from GCS
    df = pd.read_csv(
        f"gs://{IMAGE_BUCKET}/flipkart_raw_dataset/flipkart_com-ecommerce_sample.csv")
    df = df[['uniq_id',
             'product_name',
             'description',
             'brand',
             'image',
             'product_specifications']]
    
    #Ray runtime env
    runtime_env = {"pip": ["google-cloud-storage==2.16.0",
                           "spacy==3.7.4",
                           "jsonpickle==3.0.3"]}
    # Initiate a driver: start and connect with Ray cluster
    if RAY_CLUSTER_HOST != "local":
        ClientContext = ray.init(f"ray://{RAY_CLUSTER_HOST}", runtime_env=runtime_env)
        logger.debug(ClientContext)

        # Get the ID of the node where the driver process is running
        driver_process_node_id = ray.get_runtime_context().get_node_id() #HEX
        logger.debug(f"driver_process_node_id={driver_process_node_id}")
        
        logger.debug(ray.cluster_resources())
    else:
        RayContext = ray.init()
        logger.debug(RayContext)

    #Chunk the dataset
    res = split_dataframe(df)

    logger.debug('Data Preperation started')
    start_time = time.time()
    results = ray.get([get_clean_df.remote(res[i], logger, i) for i in range(len(res))])
    logger.debug('Data Preperation finished in')
    duration = time.time() - start_time
    logger.debug(f"{duration}")

    #Disconnect the worker, and terminate processes started by ray.init()
    ray.shutdown()

    #Store the preprocessed data into GCS
    result_df = pd.concat(results, axis=0, ignore_index=True)
    result_df.to_csv('gs://'+IMAGE_BUCKET +
                     '/flipkart_preprocessed_dataset/flipkart.csv', index=False)
    return result_df


def main():

    logger.info('Started')

    logger.debug(f"RAY_CLUSTER_HOST={RAY_CLUSTER_HOST}")
    logger.debug(f"IMAGE_BUCKET={IMAGE_BUCKET}")
    logger.debug(f"GCS_IMAGE_FOLDER={GCS_IMAGE_FOLDER}")

    clean_df = run_remote()

    logger.info('Finished')


if __name__ == "__main__":
    """ This is executed when run from the command line """
    main()
