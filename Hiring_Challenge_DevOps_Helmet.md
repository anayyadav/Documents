# Hiring Challenge | DevOps | Helmet

## Advanced Kubernetes Cluster Optimization

Problem: You have access to a hypothetical poorly performing Kubernetes cluster configuration manifest. This cluster is hosting multiple microservices with varying resource demands. Employ your advanced experience to conduct an in-depth analysis of the manifest and propose optimizations for enhanced performance, cost-efficiency, and fault tolerance. Assume the manifest is not directly accessible; provide detailed code snippets to showcase your modifications and optimizations.

Deliverables:
1. A comprehensive analysis of the hypothetical cluster's configuration and identified areas for improvement, considering microservices' resource demands.
2. Advanced code snippets demonstrating modifications and optimizations to the cluster configuration.
3. A strategic plan outlining the optimization approach and reasoning for each modification

### Solution

Lets segregate the problem into two parts:
1.	**K8s cluster optimisation**
    - Performance enhancement    
    - Fault tolerance and scalability of the cluster
    - Cost optimisation
2.	**Optimisation of the service deployed in K8s cluster**
    - Performance enhancement
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

    - Fault tolerance, scalability and high availability of the services deployed in K8
        - Auto scaling
        - Topology constraint
        - Pod Anti-affinity
        - Pod Disruption Budget
        - Pod priority and Pre-emption
    - Cost optimisation at service deployment level
