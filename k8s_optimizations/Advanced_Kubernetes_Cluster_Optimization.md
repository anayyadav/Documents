# Advanced Kubernetes Cluster Optimization

Problem: You have access to a hypothetical poorly performing Kubernetes cluster configuration manifest. This cluster is hosting multiple microservices with varying resource demands. Employ your advanced experience to conduct an in-depth analysis of the manifest and propose optimizations for enhanced performance, cost-efficiency, and fault tolerance. Assume the manifest is not directly accessible; provide detailed code snippets to showcase your modifications and optimizations.

Deliverables:
1. A comprehensive analysis of the hypothetical cluster's configuration and identified areas for improvement, considering microservices' resource demands.
2. Advanced code snippets demonstrating modifications and optimizations to the cluster configuration.
3. A strategic plan outlining the optimization approach and reasoning for each modification

### Solution

Lets segregate the problem into four parts:

1. Performance enhancement
    - Build optimised docker image
        1. Have small images, since big images are not so portable over the network
        2. Use container friendly OS like alpine so that they are more resistant to misconfiguration
        3. Use multi stage builds so that we deploy only the compiled application and not the dev sources that comes with it.

    - Diagnostic checks
        
        The K8s probes allows us to validate the state of the pods running in our k8s cluster.  Additionally we can use K8s probe to monitor and gather information about the other events affecting the containers, such as autoscaling.
        1. Start-up probe - This is first to start and tells Kubelet that the application within the container has successfully started. The other probes will be disabled until this probe is in a successful state.
        2. Readiness probe  - This informs K8s that the container is ready to accept the requests. If this probe is in a failed state no traffic is allocated to the pod and the pod is removed from the corresponding service.
        3. Liveness probe – It confirms whether the container is running. If the signal form the probe indicates a non running status, the kubelet picks up this signal and kills the container process. 
        > [!NOTE]
        > K8s probe do more than help us understand our application health. They also supports well-planned effective autoscaling based on health metrics
        ```console
        livenessProbe:
        failureThreshold: 6
        httpGet:
            path: /health
            port: http
            scheme: HTTP
        periodSeconds: 10
        successThreshold: 1
        timeoutSeconds: 30
        readinessProbe:
        failureThreshold: 6
        httpGet:
            path: /health
            port: http
            scheme: HTTP
        periodSeconds: 10
        successThreshold: 1
        timeoutSeconds: 30        
        ```

    - Resource constraints

        K8s orchestrate containers at scale and the heart of the mechanism is the efficient scheduling of pods into nodes. We can do that by specifying resources constraints.
        1. We can define the resource constraints by setting up request and limit
        2. Request and limits are enforced based on whether the resource is compressible or incompressible
        3. K8s divides container into 3 QOS (Quality of Service) classes
        1. Guaranteed - If limits and optionally requests (not equal to 0) are set for all resources across all containers and they are equal, then the pod is classified as Guaranteed.
        2. Burstable - If requests and optionally limits are set (not equal to 0) for one or more resources across one or more containers, and they are not equal, then the pod is classified as Burstable. When limits are not specified, they default to the node capacity
        3. Best effort - If requests and limits are not set for all of the resources, across all containers, then the pod is classified as Best-Effort.
        4. Guaranteed – Pods will be treated top priority and are guaranteed to not be killed until they exceed their limit
        5. Burstable -  Pods will have minimal resource guarantee, but can use more resources when available
        6. Best effort – Pods will be treated as Lowest priority
    
        ```console
        resources:
        limits:
            cpu: 500m
            memory: 512Mi
        requests:
            cpu: 150m
            memory: 250Mi
    
        ```

    - Node affinity or Node Selector

        Not all nodes runs on same hardware and not all service need to run are cpu intensive or memory intensive.
    
        Example - When we have a node that are suitable for CPU-intensive operations, we want to pair them with CPU-intensive services to maximize the efforts, to do that we can use nodeSelector, nodeAffinity
        
        1. nodeSelector - We can specify the node labels directly
        2. nodeAffinity - A more expressive yet specific way to schedule the pods on a node

        ```console
        nodeSelector:
            infra-node-group: compute-node
        affinity:
            nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
            - key: capacity-type
                operator: In
                values:
                - spot
                - matchExpressions:
                - key: capacity-type
                operator: In
                values:
                - on-demand
        ```

    - Graceful shutdown of pods in k8s using lifecycle hooks

        Pod are ephemeral in nature and may be killed due to a number of different reasons such as: 
        1. Being scheduled on a node that fails (In this case the pod will be deleted )
        2. Lack of resources on the node where the pods is scheduled (In this case the pod will be evicted )

        Since pods fundamentally represent process running on nodes in a cluster, it is important to ensure that when killed, they have time to clean up and terminate gracefully. 
    
        By default K8s will wait for 30 sec to allow processes to handle the TERM signal. This is known as grace period. If the grace period time runs out and the process has not gracefully exited, the container runtime will send a KILL signal, abruptly stopping the process. This is useful when a processes needs additional time to clean up (making network call, write to disk etc.)
    
        K8s allows us to define lifecycle hooks for containers, important in the context of graceful shutdown is the preStop hook, that will be called when a container is terminated due to: 
        1. An API request
        2. Liveness/Readiness probe failure
        3. Resource contention

        ```console
        ## for entire pod
        terminationGracePeriodSeconds: 60

        ## for application container 
        lifecycle:
        preStop:
        exec:
            command:
            - sh
            - '-c'
            - sleep 60
        ```
2. Fault tolerance, scalability and high availability of the services deployed in K8
    - Auto scaling

        We need to have auto-scaling in place to make our services more fault tolerant. There are two types of auto scaling.
        1. Vertical Scaling (scale up )
        - Vertical scaling has hard limit, it is impossible to add unlimited CPU and memory to a single server
        - It does not have failover and redundancy. If one pods goes down, the services goes down with it completely.
        2. Horizontal scaling (scale out)
        - It is more desirable for large scale application due to limitation of vertical scaling. 

        ```console
        apiVersion: autoscaling/v2
        kind: HorizontalPodAutoscaler
        metadata:
        name: test-service
        namespace: test-namespace
        labels:
            infra-env: prod
            infra-product: payments
            infra-service: test-service
        spec:
        scaleTargetRef:
            kind: Deployment
            name: test-service
            apiVersion: apps/v1
        minReplicas: 2
        maxReplicas: 75
        metrics:
            - type: Resource
            resource:
                name: memory
                target:
                type: Utilization
                averageUtilization: 90
            - type: Resource
            resource:
                name: cpu
                target:
                type: Utilization
                averageUtilization: 70
        behavior:
            scaleUp:
            stabilizationWindowSeconds: 0
            selectPolicy: Max
            policies:
                - type: Pods
                value: 5
                periodSeconds: 10
                - type: Percent
                value: 50
                periodSeconds: 10
            scaleDown:
            stabilizationWindowSeconds: 60
            selectPolicy: Max
            policies:
                - type: Pods
                value: 1
                periodSeconds: 300
        ```

    - Topology constraint

        Topology spread constraints uses labels to enforce specific distribution patterns. K8s uses labels to identify the topology of the nodes or zones and then define spread constraints to ensues that pods with certain labels get spread across those topologies.
        
        More the distribution lesser the disruption and therefore more fault tolerance

        ```console
        topologySpreadConstraints:
        - maxSkew: 1
            topologyKey: topology.kubernetes.io/zone
            whenUnsatisfiable: DoNotSchedule
            labelSelector:
                matchLabels:
                infra-env: prod
                infra-service: test-service
        ```

    - Pod Anti-affinity

        Pod affinity allows us to set priorities for which nodes to place our pods based on the attributes of the other pods running on those nodes. This works well for grouping pods togethers in the same node. Pod anti-affinity allows us to accomplish the opposite, ensuring certain pods don’t run on the same node as other pods. 
        
        We are going to use this to make sure our pods that run the same application are spread among multiple nodes. 
        
        > [!NOTE]
        > This will also help us in making our service deployment to handle un-even disruption in an effective manner. 
    
        ```console
        affinity:
            nodeAffinity:
                requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                    - key: capacity-type
                    operator: In
                    values:
                    - spot
                - matchExpressions:
                    - key: capacity-type
                    operator: In
                    values:
                    - on-demand
            podAntiAffinity:
                requiredDuringSchedulingIgnoredDuringExecution:
                - labelSelector:
                    matchLabels:
                    app: test-service
                    infra-env: prod
                    infra-service: test-service
                topologyKey: kubernetes.io/hostname          
        ```
    - Pod Disruption Budget
        1. PDB ensures that a minimum number of replicas are available at all times, which helps maintain the high availability of critical workloads during node maintenance or failures.
        2. This also automate the management of disruptions to workloads during node maintenance or failures, reducing the need for manual intervention
        3. By preventing too many replicas from being disrupted simultaneously, PDBs can help improve the stability of our applications
        4. By ensuring the high availability of critical workloads, PDBs can help reduce downtime and data loss, which can be costly to business.

        ```console
        apiVersion: policy/v1
        kind: PodDisruptionBudget
        metadata:
            name: test-service
            namespace: test-namespace
        spec:
            maxUnavailable: 1
            selector:
                matchLabels:
                app: test-service

        ```

    - Pod priority and Pre-emption
        1. Pod priority indicates the importance of a pod relative to other pods and queues the pods based on that priority.
        2. We can assign pods a priority class, which is a non-namespaced object that defines a mapping from a name to the integer value of the priority. The higher the value, the higher the priority.
        3. Pod pre-emption allows the cluster to evict or pre-empt, lower-priority pods so that higher priority pods can be scheduled it there is no available space on a suitable node
        4. Pod Priority also affects the scheduling order of the pods and out of resource eviction ordering on the node

        ```console
        ## At global level
        apiVersion: scheduling.k8s.io/v1
        description: Used for highly critical service pods that must run in the cluster, but can be moved to another node if necessary.
        kind: PriorityClass
        metadata:
        name: high-priority
        preemptionPolicy: PreemptLowerPriority
        value: 100000
        ```

        ```console
        ## At pod level
        spec:
          priorityClassName: high-priority
          
        ```
    - Customise deployment strategy
      
      A k8s deployment strategy is a declarative statement that defines the application lifecycle and how updates to an application should be applied.
      There are many deployment strategy out there but here we will only discuss about the deployment strategy supports in k8s out of the box.

      1. Rolling deployment  (best suited)

      It replaces the existing version of the pods with a new version, updating pods slowly one by one, without downtime
      It uses readiness probe to check if a new pod is ready, before starting to scale down pods with older version
      To refine our deployment strategy, change the following parameters

      - MaxSurge – max number of pods the deployment is allowed to create at one time
      - MaxUnavailable – specifies the max number of pods that are allowed to be unavailable during the rollout
      2. Recreate deployment
    
      This is a basic deployment pattern which simply shuts down all the old pods and replace them with new ones. 

      ```console
      strategy:
      type: RollingUpdate
      rollingUpdate:
          maxUnavailable: 0
          maxSurge: 1
      ```
3. Cost optimisation at service deployment level
    - Compute and storage cost
        1. Right sizeing of the pods
            - Overcommit CPU, memory, storage to achieve high utilization, reduce waste.
            - Manage headroom for spikes using auto-scaling and admission control.
            - Scale out with more small nodes vs vertical scaling up
            - Horizontal scaling accommodates peaks more efficiently
            - Tailor node types to workload types — GPUs for ML, high CPU for processing
            - Avoid homogenous clusters with resource imbalance
            - Set requests and limits on namespaces and pods to constrain resource usage
            - Prevent resource hogging, priority inversion
            - Adjust timeouts and connection handling for proxies and ingress
            - Tune service mesh virtual resource configurations
            - Continuously profile apps to collect utilization data
            - Update configurations and resources types to match evolving usage
            - Use arm nodes which are cheaper as compare to amd
            - Use spot nodes instead of ondeamand nodes and use fallback option to make sevice fault tolrent. 

        2. Architecting for Right Size Agility
            - Decompose monoliths into independently scalable microservices
            - Stateless services for maximum horizontal scale
            - Isolate databases, caches, message queues for independent scaling
            - Queue requests to handle spikes without overloaded resources
            - Process queue backlog with extra capacity during lulls

    - Data transfer cost

        1. Keep all the pods in single availablity zone and region if possible
        2. Use vpc endpoint if service is intracting with other AWS services to save Nat Gateway cost
4. Observability
      
    Monitoring a Kubernetes cluster can be challenging due to its intricate architecture and various components. To guarantee optimal performance and seamless application operation, it is essential to track various metrics across different aspects of the cluster

    - Node Level

      1. Node Memory Pressure
        
            By setting an alert when a node exceeds a certain percentage of memory consumption, such as 90%, we can proactively address potential issues before experiencing disruptions to your application or service.

      2. Node CPU High Utilization
        
            It appears some Pods are sensitive to CPU throttling and may experience some readiness probes failure leading to Pod restarts and eventually non-operational application or service. Hence it is importan to monitor CPU utilization of nodes

      3.  Node not in Ready state
        
            It is normal for a node to be in a non-Ready state for brief periods of time as it can be due to node draining, upgrade, and other completely normal scenarios. Above a certain period of time, however, it can indicate there is some issue with the node. For example, an “Unknown” state means the controller couldn’t communicate with the node to identify its state and it’s definitely something worth following and knowing about to ensure the cluster is running smoothly.


      4. Node Disk Pressure
        
            Running out of disk space can cause issues with the node’s overall health, even if most storage is defined and used outside of the nodes. It is important to be proactive and monitor disk space to ensure that there is enough free space and avoid potential issues.

      5. Network In and Out
        
            Monitoring the network traffic in and out of our Kubernetes nodes is crucial for identifying potential issues. By tracking network metrics, we can quickly detect and respond to alerts indicating a lack of traffic to and from a node, which may indicate a serious problem with the node. This will help us to ensure the smooth operation of your Kubernetes cluster.

    - Control Plane Level

      1. Latency in Creating Pods
        
            If it takes time for Pods to be created and start running we may an have issue with Kubelet or even the API server.
      2. kubelet State
    
            When Kubelet is experiencing issues, you may notice Pods are not being scheduled on nodes, it takes time for Pods to be created and Pods are not starting as quickly as you are used to. This is exactly why it’s so crucial to monitor Kubelet.
      3. kube-controller-manager State

            kube-controller-manager is a collection of controllers responsible for reconciling tasks to make sure the actual state meets the desired state, in objects like ReplicaSets, Deployments, PersistentVolumes, etc. So we need to monitor it and making sure it’s up.

    - Deployment Level
        1. Desired Number of Replicas vs. Running number of Replicas
            
            To track the mismatch between the two that usually means there is some issue preventing all the replicas from running.

        2. Pod creation and deletion rate
            
            To track how quickly a Deployment is scaling and identify issues with the scaling, you may want to look into monitoring the metrics for Pods creation and deletion rates.

    - Pod level
        1. OOMkilled Pods - Ensuring fair resource allocation among Pods and to prevent out-of-memory issues
        2. Pods with CPU Throttling
        3. Readiness Probe Failures
        4. Pods Running on the Right Node
        5. Too many restarts and CrashLoopBackOff
        6. Pending Pods
        7. Pods in “Unknown” state
