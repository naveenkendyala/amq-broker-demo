# AMQ Broker on OpenShift
  # Talk :: Operators and Operator Hub
  # AMQ Broker Operator and avaialble API's

# Create a project amq-broker-demo
oc new-project amq-broker-demo

# Create Broker Instance
  # Talk through Persistence
  # Journal, Storage
  # Resource Limits
  # Prometheus Metrics, Jolokia Plugin

apiVersion: broker.amq.io/v1beta1
kind: ActiveMQArtemis
metadata:
  name: artemis-broker
  application: artemis-broker-app
spec:
  deploymentPlan:
    # Number of Broker Instances
    size: 1
    # Broker Image
    image: placeholder
    initImage: placeholder    
    requireLogin: false
    persistenceEnabled: true
    journalType: nio
    # Applies only when the number of broker pods are reduced and has atleast one pod running
    messageMigration: true
    # Provide Storage that is applicable for all the broker instances
    storage:
      size: 4Gi
      storageClassName: gp2-csi
    # CPU, Memory Resources & Limits used by the Broker Instance  
    resources:
      limits:
        cpu: "500m"
        memory: "1024M"
      requests:
        cpu: "250m"
        memory: "512M"
    #Enable the Proetheus plugin
    enableMetricsPlugin: true
    #Enable the Jolokia agent
    jolokiaAgentEnabled: true
    managementRBACEnabled: false
  # Enabling Broker console access
  console:
    expose: true  
  # Configure the protocols
  acceptors:
    - name: amqp
      protocols: amqp
      port: 5672
      sslEnabled: false
      enabledProtocols: TLSv1,TLSv1.1,TLSv1.2
      needClientAuth: false
      wantClientAuth: false
      verifyHost: false
      sslProvider: JDK
      sniHost: localhost
      expose: true
      anycastPrefix: jms.queue.
      multicastPrefix: /topic/

# Lets create an address where we can send and receive messages from
apiVersion: broker.amq.io/v1beta1
kind: ActiveMQArtemisAddress
metadata:
  name: artemis-broker-address
spec:
  addressName: prices
  queueName: prices
  routingType: anycast




$ curl -k -u admin:admin http://console-broker.amq-demo.apps.example.com/console/jolokia/read/org.apache.activemq.artemis:broker=%22broker%22,component=addresses,address=%22TESTQUEUE%22,subcomponent=queues,routing-type=%22anycast%22,queue=%22TESTQUEUE%22/MaxConsumers

curl -k -u admin:admin http://artemis-broker-wconsj-0-svc-rte-amq-broker-demo.apps.cluster-hbzms.hbzms.sandbox571.opentlc.com/console/jolokia/read/org.apache.activemq.artemis:broker=artemis-broker-ss-0,destinationType=Queue,destinationName=prices/QueueSize
curl -k -u admin:admin http://artemis-broker-wconsj-0-svc-rte-amq-broker-demo.apps.cluster-hbzms.hbzms.sandbox571.opentlc.com/api/jolokia/read/org.apache.activemq:type=Broker,brokerName={{.BrokerName}},destinationType=Queue,destinationName=prices/QueueSize
curl -k -u admin:admin http://artemis-broker-ss-0.artemis-broker-hdls-svc.amq-broker-demo.svc.cluster.local:8161/console/jolokia/read/org.apache.activemq.artemis:destinationType=Queue,destinationName=prices/QueueSize

curl -k -u admin:admin http://artemis-broker-ss-0.artemis-broker-hdls-svc.amq-broker-demo.svc.cluster.local:8161/console/jolokia/read/org.apache.activemq.artemis:broker=\"amq-broker\",component=addresses,address=\"DLQ\",subcomponent=queues,routing-type=\"anycast\",queue=\"DLQ\"/MessageCount
curl -k -u admin:admin http://artemis-broker-ss-0.artemis-broker-hdls-svc.amq-broker-demo.svc.cluster.local:8161/console/jolokia/read/org.apache.activemq.artemis:module=Core,type=Server/Version

curl -k -u admin:admin http://artemis-broker-wconsj-0-svc-rte-amq-broker-demo.apps.cluster-hbzms.hbzms.sandbox571.opentlc.com:8161/console/jolokia/read/org.apache.activemq.artemis:module=Core,type=Server/Version



------------------------------
apiVersion: v1
kind: Secret
metadata:
  name: kedartemis
  namespace: amq-broker-demo
  labels:
    app: kedartemis
type: Opaque
data:
  artemis-password: "YWRtaW4="
  artemis-username: "YWRtaW4="
---
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: trigger-auth-kedartemis
  namespace: amq-broker-demo
spec:
  secretTargetRef:
    - parameter: username
      name: kedartemis
      key: artemis-username
    - parameter: password
      name: kedartemis
      key: artemis-password
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kedartemis-consumer-scaled-object
  namespace: amq-broker-demo
spec:
  scaleTargetRef:
    name: artermis-jms-consumer
  pollingInterval: 30  # Optional. Default: 30 seconds
  cooldownPeriod:  300 # Optional. Default: 300 seconds
  minReplicaCount: 0   # Optional. Default: 0
  maxReplicaCount: 100 # Optional. Default: 100
  triggers:
    - type: artemis-queue
      metadata:
        managementEndpoint: "artemis-broker-ss-0.artemis-broker-hdls-svc.amq-broker-demo.svc.cluster.local:8161"
        queueName: "prices"
        queueLength: "500"
        brokerName: "amq-broker"
        brokerAddress: "prices"
        #restApiTemplate: # Optional. Default: "http://<<managementEndpoint>>/console/jolokia/read/org.apache.activemq.artemis:broker=\"<<brokerName>>\",component=addresses,address=\"<<brokerAddress>>\",subcomponent=queues,routing-type=\"anycast\",queue=\"<<queueName>>\"/MessageCount"
        #restApiTemplate: "http://artemis-broker-ss-0.artemis-broker-hdls-svc.amq-broker-demo.svc.cluster.local:8161/console/jolokia/read/org.apache.activemq.artemis:broker=\"amq-broker\",component=addresses,address=\"prices\",subcomponent=queues,routing-type=\"anycast\",queue=\"prices\"/MessageCount"
      authenticationRef:
        name: trigger-auth-kedartemis

apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kedartemis-consumer-scaled-object
  namespace: amq-broker-demo
spec:
  scaleTargetRef:
    kind: Deployment
    name: msgconsumer-deployment
  pollingInterval: 10   # Optional. Default: 30 seconds
  cooldownPeriod:  30   # Optional. Default: 300 seconds
  idleReplicaCount: 0   # Optional.
  minReplicaCount: 1    # Optional. Default: 0
  maxReplicaCount: 10   # Optional. Default: 100
  triggers:
    - type: artemis-queue
      metadata:
        queueLength: "500"          
        restApiTemplate: "http://artemis-broker-ss-0.artemis-broker-hdls-svc.amq-broker-demo.svc.cluster.local:8161/console/jolokia/read/org.apache.activemq.artemis:broker=\"amq-broker\",component=addresses,address=\"prices\",subcomponent=queues,routing-type=\"anycast\",queue=\"prices\"/MessageCount"
      authenticationRef:
        name: trigger-auth-kedartemis
------------------------------

kind: Deployment
apiVersion: apps/v1
metadata:
  name: msgconsumer-deployment
  namespace: amq-broker-demo
spec:
  replicas: 10
  selector:
    matchLabels:
      app: msgconsumer
  template:
    metadata:
      labels:
        app: msgconsumer
    spec:
      containers:
        - name: container
          image: >-
            image-registry.openshift-image-registry.svc:5000/amq-broker-demo/artermis-jms-consumer@sha256:5f6af1fd0f45746de35c81133b84aa70d7662a848591b7f6537c7bb6d4a6b505
          ports:
            - containerPort: 8080
              protocol: TCP
          resources: {}
          imagePullPolicy: IfNotPresent
      restartPolicy: Always
      securityContext: {}
      schedulerName: default-scheduler
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 600



