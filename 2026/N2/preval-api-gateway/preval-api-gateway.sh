#!/bin/sh 
SERVICE_NAME=Servicio_de_autenticacion_chasqui 
PATH_TO_JAR=/apli/preevaluador/preval-api-gateway.jar 
PID_PATH_NAME=/tmp/preval-api-gateway-pid 
case $1 in 
start)
       echo "Starting $SERVICE_NAME ..."
  if [ ! -f $PID_PATH_NAME ]; then 
       nohup /apli/java/jdk-21.0.8/bin/java -jar  -Dspring.profiles.active=dev $PATH_TO_JAR >> /logapli/preevaluador/preval-api-gateway.log 2>&1&      
                  echo $! > $PID_PATH_NAME  
       echo "$SERVICE_NAME started ..."         
  else 
       echo "$SERVICE_NAME is already running ..."
  fi
;;
stop)
  if [ -f $PID_PATH_NAME ]; then
         PID=$(cat $PID_PATH_NAME);
         echo "$SERVICE_NAME stoping ..." 
         kill $PID;         
         echo "$SERVICE_NAME stopped ..." 
         rm $PID_PATH_NAME       
  else          
         echo "$SERVICE_NAME is not running ..."   
  fi    
;;    
restart)  
  if [ -f $PID_PATH_NAME ]; then 
      PID=$(cat $PID_PATH_NAME);    
      echo "$SERVICE_NAME stopping ..."; 
      kill $PID;           
      echo "$SERVICE_NAME stopped ...";  
      rm $PID_PATH_NAME     
      echo "$SERVICE_NAME starting ..."  
      nohup /apli/java/jdk-21.0.8/bin/java -jar  -Dspring.profiles.active=dev $PATH_TO_JAR >> /logapli/preevaluador/preval-api-gateway.log 2>&1&            
      echo $! > $PID_PATH_NAME  
      echo "$SERVICE_NAME started ..."    
  else           
      echo "$SERVICE_NAME is not running ..."    
     fi     ;;
 esac