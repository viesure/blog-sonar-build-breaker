#!/usr/bin/env sh

SONAR_RESULT="target/sonar/report-task.txt"
SONAR_SERVER="https://our.sonar.server"

if [ -z $SONAR_API_TOKEN ]
then
  echo "Sonar API Token not set"
  exit 1
fi

if [ ! -f $SONAR_RESULT ]
then
  echo "Sonar result does not exist"
  exit 1
fi

CE_TASK_ID=`sed -n 's/ceTaskId=\(.*\)/\1/p' < $SONAR_RESULT`

if [ -z $CE_TASK_ID ]
then
  echo "ceTaskId is not set from sonarbuild"
  exit 1
fi

HTTP_STATUS=$(curl -s -o /dev/null -w '%{http_code}' -u $SONAR_API_TOKEN: $SONAR_SERVER/api/ce/task\?id\=$CE_TASK_ID)

if [  "$HTTP_STATUS" -ne 200 ]
then
  echo "Sonar API Token has no access rights"
  exit 1
fi

#While report is processed ANALYSIS_ID is not availabe and jq returns null
ANALYSIS_ID=$(curl -XGET -s -u $SONAR_API_TOKEN: $SONAR_SERVER/api/ce/task\?id\=$CE_TASK_ID | jq -r .task.analysisId)
I=1
TIMEOUT=0
while [ $ANALYSIS_ID = "null" ]
do
  if [ "$TIMEOUT" -gt 30 ]
  then
    echo "Timeout of " + $TIMEOUT + " seconds exceeded for getting ANALYSIS_ID"
    exit 1
  fi
  sleep $I
  TIMEOUT=$((TIMEOUT+I))
  I=$((I+1))
  ANALYSIS_ID=$(curl -XGET -s -u $SONAR_API_TOKEN: $SONAR_SERVER/api/ce/task\?id\=$CE_TASK_ID | jq -r .task.analysisId)
done

STATUS=$(curl -XGET -s -u $SONAR_API_TOKEN: $SONAR_SERVER/api/qualitygates/project_status?analysisId=$ANALYSIS_ID | jq -r .projectStatus.status)

if [ $STATUS = "ERROR" ]
then
  echo "Qualitygate failed."
  exit 1
fi

echo "Sonar Qualitygate is OK"
exit 0
