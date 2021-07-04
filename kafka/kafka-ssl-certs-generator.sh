#!/bin/bash
# References:
# http://docs.confluent.io/2.0.0/kafka/ssl.html
# http://stackoverflow.com/questions/2846828/converting-jks-to-p12
# https://medium.com/processone/using-tls-authentication-for-your-go-kafka-client-3c5841f2a625

PASSWORD="dockerpass"
SERVER_KEYSTORE_JKS="docker.kafka.server.keystore.jks"
SERVER_KEYSTORE_P12="docker.kafka.server.keystore.p12"
SERVER_KEYSTORE_PEM="docker.kafka.server.keystore.pem"
SERVER_TRUSTSTORE_JKS="docker.kafka.server.truststore.jks"
CLIENT_TRUSTSTORE_JKS="docker.kafka.client.truststore.jks"

CLIENT_CA_PEM="ca.pem"
CLIENT_CERT_PEM="cert.pem"
CLIENT_KEY_PEM="key.pem"
CLIENT_KEYSTORE_JKS="kafka.client.keystore.jks"
CLIENT_KEYSTORE_P12="docker.kafka.client.keystore.p12"



echo "Clearing existing Kafka SSL certs..."
rm -rf certs
mkdir certs

(
echo "Generating new Kafka SSL certs..."
cd certs
# Create a kafka broker certificate

# 키스토어만들기 Generate SSL key and certificate for each Kafka broker
keytool -keystore $SERVER_KEYSTORE_JKS -alias localhost -validity 730 -genkey -storepass $PASSWORD -keypass $PASSWORD \
  -dname "CN=kafka.docker.ssl, OU=None, O=None, L=Gyeonggi, C=KR"
# CA만들기 Creating your own CA (intended to sign other certificates)
openssl req -new -x509 -keyout ca-key -out ca-cert -days 730 -passout pass:$PASSWORD \
   -subj "/C=KR/L=Gyeonggi/O=None/OU=None/CN=kafka.docker.ssl"
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

#keytool -importkeystore -srckeystore $SERVER_KEYSTORE_JKS -destkeystore $SERVER_KEYSTORE_P12 -srcstoretype JKS -deststoretype PKCS12 -srcstorepass $PASSWORD -deststorepass $PASSWORD -noprompt

# PEM for KafkaCat
# openssl pkcs12 -in $SERVER_KEYSTORE_P12 -out $SERVER_KEYSTORE_PEM -nodes -passin pass:$PASSWORD

echo "Generating telegraf CA pem..."
# to extract the Certificate Authority (CA) certificate:
#openssl pkcs12 -in $SERVER_KEYSTORE_P12 -out $CLIENT_CA_PEM -nodes -passin pass:$PASSWORD -passout pass:$PASSWORD

# keytool -importkeystore -srckeystore $SERVER_TRUSTSTORE_JKS -destkeystore server.p12 -deststoretype PKCS12 -storepass $PASSWORD -keypass $PASSWORD -noprompt
# openssl pkcs12 -in server.p12 -nokeys -out $CLIENT_CA_PEM -passin pass:$PASSWORD


keytool -importkeystore -srckeystore $SERVER_TRUSTSTORE_JKS -destkeystore server.p12 -deststoretype PKCS12
openssl pkcs12 -in server.p12 -nokeys -out ca.pem

echo "Generating telegraf client keystore..."
keytool -importkeystore -srckeystore $SERVER_KEYSTORE_JKS -destkeystore client.p12 -deststoretype PKCS12
openssl pkcs12 -in client.p12 -nokeys -out cert.pem
openssl pkcs12 -in client.p12 -nodes -nocerts -out key.pem


# convert your client keystore to be usable from Go
# keytool -importkeystore -srckeystore $SERVER_KEYSTORE_JKS -destkeystore $CLIENT_KEYSTORE_P12 -deststoretype PKCS12 -srcstorepass $PASSWORD -deststorepass $PASSWORD -noprompt
# echo "Generating telegraf client certs..."
# openssl pkcs12 -in $CLIENT_KEYSTORE_P12 -nokeys -out $CLIENT_CERT_PEM -passin pass:$PASSWORD
# openssl pkcs12 -in $CLIENT_KEYSTORE_P12 -nodes -nocerts -out $CLIENT_KEY_PEM -passin pass:$PASSWORD
#-passout pass:$PASSWORD
chmod +rx *
)
