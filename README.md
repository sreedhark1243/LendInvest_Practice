# LendInvest_Practice
This repository is for lend invest interview
--------------------------------------------------------------------------------------

IAAC: Created Using terraform
AWS IAAC through Terraform 
----------------------------------------------------------------------------------------
This code is written for POC of a basic apache instance creation with the load balancers on a high level view. Please watch my config files for more detailed description.
On a high level We have created: VPC-1, Public Subnets -3, Private Subnets -3 with the required infra components such as Security Groups, NAT Gateway, IGW, Route Tables. Along with the, 3 Ec2 with public LB and 3 with private LB in a ASG with a sample display content.

Please find the **Terraform_IAAC.md** file for the descriptive instllation details

**Multi Node Kubernetes Cluster:**
-----------------------------------------------------------------------------------------
Kubernetes cluster creation on EC2 machines: In order to create this we need to have the above infrastructure ready and no machines should get restarted in Ec2 Console.

Find the **Kubernetes_Installation.md** file for more descriprive notes of installation.

k8 cluster:
-------------

![K8 cluster](https://user-images.githubusercontent.com/100056000/179581285-feab7a79-0f60-4130-8d43-6029c86ba107.png)


**Deploying a 3 tier webapplication on kubernetes cluster**

Here we are building a application with the front end of voting-app which will update the redis database, workernode will get the details from the redis put the data in postgresSQL. result-app will dispaly the final results of the updates.

**Voting-App architechtureral diagram**
-----------------------------------------

![image](https://user-images.githubusercontent.com/100056000/179583386-9fa206c6-7db3-4b1f-8619-18a99eae436e.png)

