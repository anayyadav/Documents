# Advanced GitOps Workflow Design and Implementation:
Problem: Propose an intricate and advanced GitOps workflow for managing a sophisticated application deployment with multiple services and dependencies on Kubernetes. Assume a complex Git repository structure with placeholders for the application code, Helm Charts, and Kubernetes manifests. Leverage your advanced experience to craft a high-level, multistage GitOps workflow, and provide advanced code snippets to demonstrate how this workflow supports automatic application deployment upon changes to the repository.
Deliverables:
1. An elaborate and advanced description of the multistage GitOps workflow, detailing complex interactions and stages (without actual repository content).
2. Advanced code snippets illustrating how the proposed workflow supports continuous deployment in a complex application setup.
3. In-depth documentation explaining the advanced GitOps workflow, focusing on the intricacies demonstrated in your code snippets

## Solution

1. GitOps Workflow in detail

    GitOps is a modern way to make better IaC for delivering apps/services in K8s. It is all about dterminism, idempotence, automation, observability and many other features.

    * How GitOps works
        
        When we think about GitOps the first thing that comes in our head is that there is Git repository and in that repository we have YAML files describing the state of servies in K8s. For example deployments, services, ingress, secrets etc.

        On the other hand ther is a K8s cluster with all our resourecs forming our application/service.

        The only missing piece is a GitOps operator, which is reasponsible for syncing the state from Git into the K8s cluster. To sync the changes it periodically or by event does following operations
            - Reads the state from the Git 
            - Reads the state from the K8s cluster
            - Compare them
            - Changes the state of the resources depoyed in K8s if needed. 
        
        To enable GitOps, there are many tools/operators in the market now and ArgoCD is one of the CNCF incubating projects.

        One key ingredient to enable GitOps is to have the CI separate from CD. Once CI execution is done, the artifact will be push to the repository and ArgoCD will take care of the CD.

        ![CICD With GitOps](image.png)

        As you can see in the above diagram, the GitOps operator lives within the clsuter and is using pull based deployment machanism.
    
    * Pros of GitOps approach

        - Automation

            With GitOps we make neither manual changes in K8s, nor manual actions to sync the state from Git. The GitOps operator is responsible for keeping everything in sync and it does it automatically.
        - Convergence

            Our system tends to come to the desired state and even if it becomes, occasionally out of sync the GitOps operator will bring it back on its own.
        - Rollbacks and rollout

            GitOps operator like ArgoCD has nice UI where in Developer/QA guys can see the status of rollout and rollback.
        
        - State visibility
            We can easliy see following state
            1. Last sync 
            2. Health Status
            3. Current Status
            4. Real time updates
        
2. Implementation

    * prerequisite
        - Must have ArgoCD install as we are using ArgoCD as GitOps operator in our usecase
        - We must have K8s manifest or Helm charts of the services in a repository
        - We must have a seprate repository called state-repository in which we will have our values.yaml or K8s manifest files in an organised manner

    Here we will take the example of the earlier problem statement where in we have a backend service which we will be deploying using ArgoCD a GitOps Operator

    Please check the helm Chart here - https://github.com/anayyadav/Documents/tree/main/helm_chart_and_deployment_strategy


    1. Create a project in ArgoCD
        Here we are creating a logical grouping of our appicaiton with access restrications.

        We are allowing all the git repos to be used by this project, all the namespace as a destination that the project can deploy to. 

        We can also create project role with set of permisions called policies to grant specfic acces to project applications. 

        ```console
        apiVersion: argoproj.io/v1alpha1
        kind: AppProject
        metadata: 
            name: Project-A
            namespace: argocd
        spec:
            description: Argo CD poc
            sourceRepos:
                - "*"
            destination:
                - server: "*"
                namespace: "*"
            clusterResourceWhitelist: 
                - group: "*"
                kind: "*"
            namespaceResourceWhitelist: 
                - group: "*"
                kind: "*"

        ``` 

    2. Registor our private helm repos in ArgoCD
        ```console
        apiVersion: v1
        kind: secret
        metadata:
            name: private-repo
            namespace: argocd
        labels:
            argocd:argoproj.io/secret-type: repository
        stringData:
            type: helm 
            url: git@github.com:anayyadav/Documents.git
            sshPrivateKey: | <ssh key>
        ```
    
    3. Create the application with a helm as source and K8s as detination
        ```console
        apiVersion: argoproj.io/v1alpha1
        kind: Application
        metadata:
            name: Backend-servcie
            namespace: argocd

        spec:
            destination: 
            project: Project-A
            source:
                chart: backend-service
                repoUrl: git@github.com:anayyadav/Documents.git/
                targetRevision: 
            helm: 
                releaseName: Backend-service
            detination:
                server: "https://kubernetes.default.svc"
                namespace: demo
            syncPolicy:
                syncOptions:
                    - createNamespace: true

       ```
    4. Once these are configured, we can login to argocd and click on sync now. And our servic will be deployed and we can also see the rollout status.