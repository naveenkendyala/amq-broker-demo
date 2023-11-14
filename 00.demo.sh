# Install the Operator

# Create a project amq-broker-demo
oc new-project amq-broker-demo

# Sample Broker 
apiVersion: broker.amq.io/v1beta1
kind: ActiveMQArtemis
metadata:
  name: ex-aao
spec:
  deploymentPlan:
    # Number of Broker Instances
    size: 2
    # Broker Image
    image: placeholder
    requireLogin: false
    persistenceEnabled: true
    journalType: nio
    # Applies only when the number of broker pods are reduced and has atleast one pod running
    messageMigration: true
    initImage: placeholder    
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
  # Enabling Broker console access
  console:
    expose: true

# 