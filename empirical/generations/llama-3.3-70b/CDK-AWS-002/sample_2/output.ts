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

    const cluster = new eks.FargateCluster(this, 'Cluster', {
      vpc: vpc,
    });

    const taskDefinition = new eks.FargateTaskDefinition(this, 'TaskDefinition', {
      cpu: 256,
      memoryLimitMiB: 512,
    });

    const container = taskDefinition.addContainer('Container', {
      image: eks.ContainerImage.fromRegistry('amazonlinux'),
      portMappings: [
        {
          containerPort: 80,
          hostPort: 80,
          protocol: eks.Protocol.TCP,
        },
      ],
    });

    const service = new eks.FargateService(this, 'Service', {
      cluster: cluster,
      taskDefinition: taskDefinition,
    });

    const alb = new elbv2.ApplicationLoadBalancer(this, 'ALB', {
      vpc: vpc,
      internetFacing: true,
    });

    const certificate = acm.Certificate.fromCertificateArn(this, 'Certificate', 'arn:aws:acm:REGION:ACCOUNT_ID:certificate/CERTIFICATE_ID');

    const listener = alb.addListener('Listener', {
      port: 443,
      certificates: [certificate],
    });

    listener.addTargets('Targets', {
      port: 80,
      targets: [service],
    });

    listener.addAction('DefaultAction', {
      priority: 10,
      conditions: [
        elbv2.ListenerCondition.hostHeaders(['*']),
      ],
      action: elbv2.ListenerAction.forward([service]),
    });

    new cdk.CfnOutput(this, 'LoadBalancerDNS', {
      value: alb.loadBalancerDnsName,
    });
  }
}