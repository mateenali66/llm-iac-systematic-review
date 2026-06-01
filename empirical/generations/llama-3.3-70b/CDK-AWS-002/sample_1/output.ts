import * as cdk from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import * as acm from 'aws-cdk-lib/aws-certificatemanager';

export class EksFargateStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, 'Vpc', {
      cidr: '10.0.0.0/16',
      maxAzs: 3,
      subnetConfiguration: [
        {
          cidrMask: 24,
          name: 'public',
          subnetType: ec2.SubnetType.PUBLIC,
        },
        {
          cidrMask: 24,
          name: 'private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_NAT,
        },
      ],
    });

    const cluster = new eks.Cluster(this, 'Cluster', {
      vpc,
      clusterName: 'eks-fargate-cluster',
      defaultCapacity: 0,
      endpointAccess: eks.EndpointAccess.PUBLIC,
    });

    const fargateProfile = cluster.addFargateProfile('FargateProfile', {
      selectors: [
        {
          namespace: 'default',
        },
      ],
    });

    const alb = new elbv2.ApplicationLoadBalancer(this, 'ALB', {
      vpc,
      internetFacing: true,
    });

    const certificate = acm.Certificate.fromCertificateArn(
      this,
      'Certificate',
      'arn:aws:acm:REGION:ACCOUNT_ID:certificate/CERTIFICATE_ID'
    );

    const listener = alb.addListener('Listener', {
      port: 443,
      certificates: [certificate],
    });

    const service = new eks.FargateService(this, 'Service', {
      cluster,
      taskDefinition: new eks.FargateTaskDefinition(this, 'TaskDefinition', {
        cpu: 256,
        memoryLimitMiB: 512,
      }),
      service_name: 'microservice',
    });

    const targetGroup = new elbv2.ApplicationTargetGroup(this, 'TargetGroup', {
      vpc,
      port: 80,
    });

    listener.addTargetGroups('TargetGroup', {
      targetGroups: [targetGroup],
    });

    targetGroup.addTarget(service);

    new cdk.CfnOutput(this, 'LoadBalancerDNS', {
      value: alb.loadBalancerDnsName,
      description: 'The DNS name of the load balancer',
    });
  }
}