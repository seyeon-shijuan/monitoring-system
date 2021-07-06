#!/bin/bash
# References:
# https://github.com/trastle/docker-kafka-ssl
# http://docs.confluent.io/2.0.0/kafka/ssl.html
# http://stackoverflow.com/questions/2846828/converting-jks-to-p12
# https://medium.com/processone/using-tls-authentication-for-your-go-kafka-client-3c5841f2a625

PASSWORD="dockerpass"
SERVER_KEYSTORE_JKS="docker.kafka.server.keystore.jks"
SERVER_KEYSTORE_P12="docker.kafka.server.keystore.p12"
SERVER_KEYSTORE_PEM="docker.kafka.server.keystore.pem"
SERVER_TRUSTSTORE_JKS="docker.kafka.server.truststore.jks"
CLIENT_TRUSTSTORE_JKS="docker.kafka.client.truststore.jks"

CLIPASS="clientpass"
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
#######################################################################
#                 Create a kafka broker certificate                   #
#######################################################################
#2. 키스토어만들기 Generate SSL key and certificate for each Kafka broker
echo "2. Creating server.keystore.jks with keyalg rsa"
# keytool -keystore $SERVER_KEYSTORE_JKS -alias localhost -validity 730 -genkey -storepass $PASSWORD -keypass $PASSWORD \
#   -dname "CN=kafka.docker.ssl, OU=None, O=None, L=Gyeonggi, C=KR" previous cmd
keytool -keystore $SERVER_KEYSTORE_JKS -alias localhost -validity 730 -genkey -storepass $PASSWORD -keypass $PASSWORD \
  -dname "CN=kafka.docker.ssl, OU=None, O=None, L=Gyeonggi, C=KR" -storetype pkcs12 -keyalg RSA -noprompt
keytool -list -v -keystore $SERVER_KEYSTORE_JKS -storepass $PASSWORD
#1. CA만들기 Creating your own CA (intended to sign other certificates)
echo "1. Creating file ca-cert and the priv.key ca-key without password"
# openssl req -new -x509 -keyout ca-key -out ca-cert -days 730 -passout pass:$PASSWORD \
   # -subj "/C=KR/L=Gyeonggi/O=None/OU=None/CN=kafka.docker.ssl" previous cmd
openssl req -new -newkey rsa:4096 -x509 -keyout ca-key -out ca-cert -days 730 \
  -subj "/C=KR/L=Gyeonggi/O=None/OU=None/CN=kafka.docker.ssl" -nodes
keytool -printcert -v -file ca-cert
#4. 서버&클라이언트 트러스트스토어 만들고 ca-cert 임포트하기 (사인안한 raw file인 ca-cert 부르면 됨) to add the generated CA to the clients’ truststore so that the clients can trust this CA:
echo "4. Trusting the CA by creating a truststore and importing the ca-cert"
keytool -keystore $SERVER_TRUSTSTORE_JKS -alias CARoot -import -file ca-cert -storepass $PASSWORD -keypass $PASSWORD -keyalg RSA -noprompt
keytool -keystore $CLIENT_TRUSTSTORE_JKS -alias CARoot -import -file ca-cert -storepass $PASSWORD -keypass $PASSWORD -keyalg RSA -noprompt

#######################################################################
#  Signing all certificates in the keystore with the CA we generated  #
#######################################################################
#3-1. 서티리퀘스트 파일 만들기->CA가 사인할 예정 3-1: to export the certificate from the keystore:
echo "3-1. Creating a certification request file, to be signed by the CA"
keytool -keystore $SERVER_KEYSTORE_JKS -alias localhost -certreq -file cert-file -storepass $PASSWORD -keypass $PASSWORD  -keyalg RSA -noprompt
#3-2. CA로 서버 서티리퀘스트 파일 사인하기 3-2: sign it with the CA:
echo "3-2. Signing the server certificate => output: cert-signed"
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file -out cert-signed -days 730 -CAcreateserial -passin pass:$PASSWORD
echo "3-3. check local server certificates"
keytool -printcert -v -file cert-signed
keytool -list -v -keystore $SERVER_KEYSTORE_JKS -storepass $PASSWORD
#5. CA랑 사인된 서버서티를 키스토어에 임포트하기
echo "5. Importing CA and the signed server certificate into the keystore"
keytool -keystore $SERVER_KEYSTORE_JKS -alias CARoot -import -file ca-cert -storepass $PASSWORD -keypass $PASSWORD -noprompt
keytool -keystore $SERVER_KEYSTORE_JKS -alias localhost -import -file cert-signed -storepass $PASSWORD -keypass $PASSWORD -noprompt
echo "5. Creating server keystore p12"
keytool -importkeystore -srckeystore $SERVER_KEYSTORE_JKS -destkeystore $SERVER_KEYSTORE_P12 -srcstoretype JKS -deststoretype PKCS12 -srcstorepass $PASSWORD -deststorepass $PASSWORD -noprompt

#######################################################################
#                   Creating a client certificate                     #
#######################################################################
echo "creating ca.pem(ca-cert) cert.pem key.pem"
openssl pkcs12 -nodes -in $SERVER_KEYSTORE_JKS -out ca.pem -passin pass:$PASSWORD

echo "keytool creation"
keytool -importkeystore -srckeystore $SERVER_KEYSTORE_JKS -destkeystore client.p12 -deststoretype PKCS12 -srcstorepass $PASSWORD -storepass $PASSWORD -noprompt
echo "cert.pem creation"
openssl pkcs12 -in client.p12 -nokeys -out cert.pem -passin pass:$PASSWORD
echo "key.pem creation"
openssl pkcs12 -in client.p12 -nodes -nocerts -out key.pem -passin pass:$PASSWORD


chmod +rx *
)
