# webpagetest-utils

Collection of scripts to automate / expand webpagetest on AWS


## Pre-requisites

* [AWS account](http://aws.amazon.com/)
* [AWS command lines tools](http://aws.amazon.com/cli/)
* Security group rule allowing you to connect to port 80 on the server
* Security group rule allowing test agents to talk to server
* Security group rule allowing you to connect to port 22(SSH) and 3389(RDP) [OPTIONAL]
![Security group screenshoot](/../screenshot/screenshots/security_group.png?raw=true)


## Creating the instances


#### Set variables

`KEY` contains the secret key used between the agents and the server. If you don't have `pwgen` or prefer 
to use a custom key just replace the code below with your prefered password

```bash
KEY=$(pwgen --ambiguous 40 1)
REGION="eu-west-1"
OUTPUT="/tmp/webpagetest-server.out"
PROFILE="default"
SSH_KEY="webpagetest"
SERVER_AMI="ami-748e2903"
SERVER_SIZE="c3.large"
AGENT_AMI="ami-ecb3409b"
AGENT_SIZE="m3.medium"
```

#### Lauch webpagetest server

```bash
CLOUD_INIT_SCRIPT="curl https://raw.githubusercontent.com/gburiola/webpagetest-utils/master/install-webpagetest.sh"
ENC_USER_DATA=$(sed "s/secret_key_placeholder/${KEY}/" $CLOUD_INIT_SCRIPT | base64 --wrap=0)
aws ec2 run-instances \
  --profile $PROFILE \
  --count 1 \
  --key-name $SSH_KEY \
  --region $REGION \
  --image-id $SERVER_AMI \
  --user-data "$ENC_USER_DATA" \
  --instance-type $SERVER_SIZE \
  --output json > $OUTPUT
```

#### Get public hostname of your server
This information is used to configure the test agents
This is usually available a few seconds **after** you create a new instance
```bash
INSTANCE=$(grep InstanceId $OUTPUT | head -1 | awk -F\" '{print $4}')
SERVER=$(aws ec2 --profile $PROFILE describe-instances --output json --instance-ids $INSTANCE | grep PublicDnsName | head -1 | awk -F\" '{print $4}')
```

#### Launch webpagetest test agents

Set variables for user-data
```bash
AGENT_USER_DATA="wpt_server=${SERVER} wpt_key=${KEY} wpt_location=${REGION}"
AGENT_ENC_USER_DATA=$(echo $USER_DATA | base64 --wrap=0)
```

Launch on demand instances
```bash
aws ec2 run-instances \
  --profile $PROFILE \
  --count 1 \
  --region $REGION \
  --image-id $AGENT_AMI \
  --user-data "$AGENT_ENC_USER_DATA" \
  --instance-type $AGENT_SIZE
```

Launch spot instances
```bash
aws ec2 request-spot-instances \
  --profile $PROFILE \
  --spot-price "0.075" \
  --instance-count 1 \
  --region $REGION \
  --type "one-time" \
  --launch-specification "{\"ImageId\":\"${AGENT_AMI}\",\"InstanceType\":\"${AGENT_SIZE}\",\"UserData\":\"${AGENT_ENC_USER_DATA}\"}"
```


## Running the tests

```bash
URL=www.net-a-porter.com/apac/Shop/Whats-New
RUNS=3
curl -v "http://$SERVER/runtest.php?url=${URL}&runs=${RUNS}&location=${REGION}_wptdriver:Chrome"
```


## Additional info

If you need to connect to the Windows test agents to troubleshoot anything use:
```
user: administrator
password: 2dialit
```

As described on the webpagetest documentation, the AMI search on the AWS console doesn't always work. It does work on the command line. To view all available test agent AMIs on a specific region run:
```
aws ec2 describe-images \
  --region $REGION \
  --owners 314854558937 \
  --output json
```

## Links

https://sites.google.com/a/webpagetest.org/docs/private-instances
http://www.webpagetest.org/
https://github.com/WPO-Foundation/webpagetest
