#!/bin/bash
# References:
# http://docs.confluent.io/2.0.0/kafka/ssl.html
# http://stackoverflow.com/questions/2846828/converting-jks-to-p12

PASSWORD="dockerpass"
SERVER_KEYSTORE_JKS="docker.kafka.server.keystore.jks"
SERVER_KEYSTORE_P12="docker.kafka.server.keystore.p12"
SERVER_KEYSTORE_PEM="docker.kafka.server.keystore.pem"
SERVER_TRUSTSTORE_JKS="docker.kafka.server.truststore.jks"
CLIENT_TRUSTSTORE_JKS="docker.kafka.client.truststore.jks"

CLIPASS="clientpass"
CLIENT_KEYSTORE_JKS="kafka.client.keystore.jks"

echo "Clearing existing Kafka SSL certs..."
rm -rf certs
mkdir certs

(
echo "Generating new Kafka SSL certs..."
cd certs
# Create a kafka broker certificate

# 키스토어만들기 Generate SSL key and certificate for each Kafka broker
keytool -keystore $SERVER_KEYSTORE_JKS -alias localhost -validity 730 -genkey -storepass $PASSWORD -keypass $PASSWORD \
  -dname "CN=kafka.docker.ssl, OU=None, O=None, L=Gyeonggi, S=None, C=KR"
# CA만들기 Creating your own CA (intended to sign other certificates)
openssl req -new -x509 -keyout ca-key -out ca-cert -days 730 -passout pass:$PASSWORD \
   -subj "/C=KR/S=None/L=Gyeonggi/O=None/OU=None/CN=kafka.docker.ssl"
# 서버&클라이언트 트러스트스토어 만들고 ca-cert 임포트하기 to add the generated CA to the clients’ truststore so that the clients can trust this CA:
keytool -keystore $SERVER_TRUSTSTORE_JKS -alias CARoot -import -file ca-cert -storepass $PASSWORD -keypass $PASSWORD -noprompt
keytool -keystore $CLIENT_TRUSTSTORE_JKS -alias CARoot -import -file ca-cert -storepass $PASSWORD -keypass $PASSWORD -noprompt
# Signing all certificates in the keystore with the CA we generated
# 서티리퀘스트 파일 만들기->CA가 사인할 예정 1: to export the certificate from the keystore:
keytool -keystore $SERVER_KEYSTORE_JKS -alias localhost -certreq -file cert-file -storepass $PASSWORD -noprompt
# CA로 서버 서티리퀘스트 파일 사인하기 2: sign it with the CA:
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file -out cert-signed -days 730 -CAcreateserial -passin pass:$PASSWORD
# CA랑 사인된 서버서티를 키스토어에 임포트하기 to import both the certificate of the CA and the signed certificate into the keystore
keytool -keystore $SERVER_KEYSTORE_JKS -alias CARoot -import -file ca-cert -storepass $PASSWORD -keypass $PASSWORD -noprompt
keytool -keystore $SERVER_KEYSTORE_JKS -alias localhost -import -file cert-signed -storepass $PASSWORD -keypass $PASSWORD -noprompt

keytool -importkeystore -srckeystore $SERVER_KEYSTORE_JKS -destkeystore $SERVER_KEYSTORE_P12 -srcstoretype JKS -deststoretype PKCS12 -srcstorepass $PASSWORD -deststorepass $PASSWORD -noprompt

# PEM for KafkaCat
#openssl pkcs12 -in $SERVER_KEYSTORE_P12 -out $SERVER_KEYSTORE_PEM -nodes -passin pass:$PASSWORD

chmod +rx *

mkdir cli-certs
echo "Generating new Kafka client SSL certs..."
cd cli-certs

# 클라이언트 서티만들기 to make client keystore
keytool -keystore $CLIENT_KEYSTORE_JKS -alias client -validity 730 -genkey -storepass $CLIPASS -keypass $CLIPASS \
  -dname "CN=kafka.docker.ssl.client, OU=None, O=None, L=Gyeonggi, S=None, C=KR" -storetype pkcs12
# 서티 리퀘스트 파일 만들기 ->CA가 사인할 예정 to make certificate request file -> to be signed by CA
keytool -keystore $CLIENT_KEYSTORE_JKS -alias client -certreq -file logstash-cert-sign-request-file -storepass $CLIPASS -keypass $CLIPASS -noprompt

)
