# Hiring Challenge | DevOps | Helmet

## Advanced Kubernetes Cluster Optimization

Problem: You have access to a hypothetical poorly performing Kubernetes cluster configuration manifest. This cluster is hosting multiple microservices with varying resource demands. Employ your advanced experience to conduct an in-depth analysis of the manifest and propose optimizations for enhanced performance, cost-efficiency, and fault tolerance. Assume the manifest is not directly accessible; provide detailed code snippets to showcase your modifications and optimizations.

Deliverables:
1. A comprehensive analysis of the hypothetical cluster's configuration and identified areas for improvement, considering microservices' resource demands.
2. Advanced code snippets demonstrating modifications and optimizations to the cluster configuration.
3. A strategic plan outlining the optimization approach and reasoning for each modification

### Solution

Lets segregate the problem into two parts:
1.	K8s cluster optimisation
    - Performance enhancement    
    - Fault tolerance and scalability of the cluster
    - Cost optimisation
2.	Optimisation of the service deployed in K8s cluster
    - Performance enhancement
        - Build optimised docker image
          1. Have small images, since big images are not so portable over the network
          2. Use container friendly OS like alpine so that they are more resistant to misconfiguration
          3. Use multi stage builds so that we deploy only the compiled application and not the dev sources that comes with it.
        - Diagnostic checks
        - Resource constraints
        - Node affinity or Node Selector
        - Graceful shutdown of pods in k8s using lifecycle hooks
    - Fault tolerance, scalability and high availability of the services deployed in K8
        - Auto scaling
        - Topology constraint
        - Pod Anti-affinity
        - Pod Disruption Budget
        - Pod priority and Pre-emption
    - Cost optimisation at service deployment level
