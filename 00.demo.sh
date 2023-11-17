#----------------------------------------------------------------------------------------
# Show the cluser is in the AWS
# Showcase the empty cluster
#----------------------------------------------------------------------------------------
# Create a project amq-broker-demo
oc new-project amq-broker-demo
#----------------------------------------------------------------------------------------
# AMQ Broker on OpenShift
  # Talk :: Operators and Operator Hub
  # AMQ Broker Operator and avaialble API's
#----------------------------------------------------------------------------------------
# Create Broker Instance
  # Talk through Persistence
  # Journal, Storage
  # Resource Limits
  # Prometheus Metrics, Jolokia Plugin

apiVersion: broker.amq.io/v1beta1
kind: ActiveMQArtemis
metadata:
  name: artemis-broker
  namespace: amq-broker-demo
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
    #Enable the Prometheus plugin
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

#----------------------------------------------------------------------------------------
# Show the Routes
# Talk about the console route
# 
# 
#----------------------------------------------------------------------------------------
# Lets create an address where we can send and receive messages from
# Once created, showcase the address is present in the broker
apiVersion: broker.amq.io/v1beta1
kind: ActiveMQArtemisAddress
metadata:
  name: artemis-broker-address
  namespace: amq-broker-demo
spec:
  addressName: demoqueue
  queueName: demoqueue
  routingType: anycast

#----------------------------------------------------------------------------------------
# Create a producer of the messages
# Go to "amq-broker-demo/client-examples/artermis-jms-producer"
# mvn clean compile package
# Show the messages are being produced on the "demoqueue"

kind: Deployment
apiVersion: apps/v1
metadata:
  name: msg-producer
  namespace: amq-broker-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: msgproducer
  template:
    metadata:
      labels:
        app: msgproducer
    spec:
      containers:
        - name: container
          image: quay.io/naveenkendyala/artemis-jms-producer:v1.0.0
          ports:
            - containerPort: 8080
              protocol: TCP
          resources: {}
          imagePullPolicy: Always
      restartPolicy: Always
      securityContext: {}
      schedulerName: default-scheduler

#----------------------------------------------------------------------------------------
# Create a consumer of the messages
# Go to "amq-broker-demo/client-examples/artermis-jms-consumer"
# mvn clean compile package
# Show the messages are being consumed on the "demoqueue"

# Create a consumer of the messages
kind: Deployment
apiVersion: apps/v1
metadata:
  name: msg-consumer
  namespace: amq-broker-demo
spec:
  replicas: 1
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
          image: quay.io/naveenkendyala/artemis-jms-consumer:v1.0.0
          ports:
            - containerPort: 8080
              protocol: TCP
          resources: {}
          imagePullPolicy: Always
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
#----------------------------------------------------------------------------------------
# Jolokia
# Allows to expose the JMX beans in a RESTful manner
# Showcase the endpoint with authentication about how to get the queue depth
  # Navigate to the Fuse Console : admin/admin
  # Go to the JMX and navigate to the jolokia --> serverHandler --> hawtio. Click on Operations tab --> mBeanServersInfo()
  # Talk through what is exposed
# Show the pending message count
curl -k -u admin:admin http://artemis-broker-ss-0.artemis-broker-hdls-svc.amq-broker-demo.svc.cluster.local:8161/console/jolokia/read/org.apache.activemq.artemis:broker=\"amq-broker\",component=addresses,address=\"demoqueue\",subcomponent=queues,routing-type=\"anycast\",queue=\"demoqueue\"/MessageCount

#----------------------------------------------------------------------------------------
# Operator :: Keda
  # Talk :: Operators and Operator Hub
  # Keda Operator and avaialble API's

apiVersion: keda.sh/v1alpha1
kind: KedaController
metadata:
  name: keda
  namespace: openshift-keda
spec:
  admissionWebhooks:
    logEncoder: console
    logLevel: info
  metricsServer:
    logLevel: '0'
  operator:
    logEncoder: console
    logLevel: info
  watchNamespace: amq-broker-demo

#----------------------------------------------------------------------------------------
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
#----------------------------------------------------------------------------------------
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
#----------------------------------------------------------------------------------------
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
  idleReplicaCount: 0   # Optional.
  minReplicaCount: 0   # Optional. Default: 0
  maxReplicaCount: 100 # Optional. Default: 100
  triggers:
    - type: artemis-queue
      metadata:
        managementEndpoint: "artemis-broker-ss-0.artemis-broker-hdls-svc.amq-broker-demo.svc.cluster.local:8161"
        queueName: "prices"
        queueLength: "500"
        brokerName: "amq-broker"
        brokerAddress: "demoqueue"
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
    name: msg-consumer
  pollingInterval: 10   # Optional. Default: 30 seconds
  cooldownPeriod:  30   # Optional. Default: 300 seconds
  idleReplicaCount: 0   # Optional.
  minReplicaCount: 1    # Optional. Default: 0
  maxReplicaCount: 10   # Optional. Default: 100
  triggers:
    - type: artemis-queue
      metadata:
        queueLength: "500"          
        restApiTemplate: "http://artemis-broker-ss-0.artemis-broker-hdls-svc.amq-broker-demo.svc.cluster.local:8161/console/jolokia/read/org.apache.activemq.artemis:broker=\"amq-broker\",component=addresses,address=\"demoqueue\",subcomponent=queues,routing-type=\"anycast\",queue=\"demoqueue\"/MessageCount"
      authenticationRef:
        name: trigger-auth-kedartemis
#----------------------------------------------------------------------------------------
# Cretae the dc and rc
oc project amq-broker-dc
oc project amq-broker-rc

#----------------------------------------------------------------------------------------
# Create Broker Instance : amq-broker-rc
  # Talk through Persistence
  # Journal, Storage
  # Resource Limits
  # Prometheus Metrics, Jolokia Plugin

apiVersion: broker.amq.io/v1beta1
kind: ActiveMQArtemis
metadata:
  name: artemis-broker
  namespace: amq-broker-rc
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
    #Enable the Prometheus plugin
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


# Create Broker Instance : amq-broker-rc
  # Talk through Persistence
  # Journal, Storage
  # Resource Limits
  # Prometheus Metrics, Jolokia Plugin

apiVersion: broker.amq.io/v1beta1
kind: ActiveMQArtemis
metadata:
  name: artemis-broker
  namespace: amq-broker-dc
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
    #Enable the Prometheus plugin
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
  #
  brokerProperties:
  - "AMQPConnections.target.uri=tcp://artemis-broker-amqp-0-svc.amq-broker-rc.svc.cluster.local:5672"
  - "AMQPConnections.target.connectionElements.mirror.type=MIRROR"
  - "AMQPConnections.target.connectionElements.mirror.messageAcknowledgements=true"
  - "AMQPConnections.target.connectionElements.mirror.queueCreation=true"
  - "AMQPConnections.target.connectionElements.mirror.queueRemoval=true"

#----------------------------------------------------------------------------------------
# Lets create an address where we can send and receive messages from
apiVersion: broker.amq.io/v1beta1
kind: ActiveMQArtemisAddress
metadata:
  name: artemis-broker-address
  namespace: amq-broker-dc
spec:
  addressName: demoqueue
  queueName: demoqueue
  routingType: anycast

#----------------------------------------------------------------------------------------
# Create a producer directly

kind: Deployment
apiVersion: apps/v1
metadata:
  name: msg-producer
  namespace: amq-broker-dc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: msgproducer
  template:
    metadata:
      labels:
        app: msgproducer
    spec:
      containers:
        - name: container
          image: quay.io/naveenkendyala/artemis-jms-producer:v1.0.0
          ports:
            - containerPort: 8080
              protocol: TCP
          resources: {}
          imagePullPolicy: Always
      restartPolicy: Always
      securityContext: {}
      schedulerName: default-scheduler


#----------------------------------------------------------------------------------------
# Create a consumer directly

kind: Deployment
apiVersion: apps/v1
metadata:
  name: msg-consumer
  namespace: amq-broker-dc
spec:
  replicas: 1
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
          image: quay.io/naveenkendyala/artemis-jms-consumer:v1.0.0
          ports:
            - containerPort: 8080
              protocol: TCP
          resources: {}
          imagePullPolicy: Always
      restartPolicy: Always
      securityContext: {}
      schedulerName: default-scheduler

