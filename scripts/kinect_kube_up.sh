#!/bin/bash
# for farming out modeling jobs the e-z way

hash gcloud 2>/dev/null || { echo >&2 "gcloud not installed.  Aborting."; exit 1; }

if [ -z "${KINECT_GKE_CLUSTER_NAME}" ]; then
	CLUSTERNAME="test-cluster"
else
	echo "Setting cluster name to ${KINECT_GKE_CLUSTER_NAME}"
	CLUSTERNAME="${KINECT_GKE_CLUSTER_NAME}"
fi

if [ -z "${KINECT_GKE_MACHINE_TYPE}" ]; then
	MACHINETYPE="n1-standard-2"
else
	echo "Setting machine type to ${KINECT_GKE_MACHINE_TYPE}"
	MACHINETYPE=${KINECT_GKE_MACHINE_TYPE}
fi

if [ -z "${KINECT_GKE_NUM_NODES}" ]; then
	NUMNODES="3"
else
	echo "Setting number of nodes to ${KINECT_GKE_NUM_NODES}"
	NUMNODES=${KINECT_GKE_NUM_NODES}
fi

if [ -z "${KINECT_GKE_SCOPES}" ]; then
	SCOPES="storage-full"
else
	echo "Setting scopes to ${KINECT_GKE_SCOPES}"
	SCOPES=${KINECT_GKE_SCOPES}
fi

AUTHORIZE=false

if [ -z "${KINECT_GKE_PREEMPTIBLE}" ]; then
	PREEMPTIBLE=false
else
	echo "Setting preemptible to ${KINECT_GKE_PREEMPTIBLE}"
	PREEMPTIBLE=${KINECT_GKE_PREEMPTIBLE}
fi

if [ -z "${KINECT_GKE_AUTOSCALE}" ]; then
	AUTOSCALE=false
else
	echo "Setting autoscale to ${KINECT_GKE_AUTOSCALE}"
	AUTOSCALE=${KINECT_GKE_AUTOSCALE}
fi

DRYRUN=false

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -c|--cluster-name)
    CLUSTERNAME="$2"
    shift # past argument
    ;;
    -m|--machine-type)
    MACHINETYPE="$2"
    shift # past argument
    ;;
    -n|--num-nodes)
    NUMNODES="$2"
    shift # past argument
    ;;
		-s|--scope)
		SCOPE="$2"
		shift
		;;
		-a|--authorize)
		AUTHORIZE=true
		shift
		;;
		-p|--preemptible)
		PREEMPTIBLE=true
		shift
		;;
		-d|--dry-run)
		DRYRUN=true
		shift
		;;
		--auto-scale)
		AUTOSCALE=true
		;;
		*)
            # unknown option
    ;;
esac
shift
done

if [ "${AUTHORIZE}" = true ]; then
	gcloud auth application-default login
fi

# can make preemptible

COMMAND="gcloud container clusters create ${CLUSTERNAME} --scopes ${SCOPES} --machine-type ${MACHINETYPE} --num-nodes ${NUMNODES}"

if [ "${PREEMPTIBLE}" = true ]; then
	COMMAND+=" --preemptible"
fi

if [ "${AUTOSCALE}" = true ]; then
	COMMAND+=" --enable-autoscaling --min-nodes 1 --max-nodes ${NUMNODES}"
fi

CREDENTIALS="gcloud container clusters get-credentials ${CLUSTERNAME}"

echo $COMMAND
echo $CREDENTIALS

if [ "${DRYRUN}" = false ]; then

	eval $COMMAND
	eval $CREDENTIALS
	# mos def gotta kill kubectl proxy if it exists

	PROXY_PID=$(pgrep -f "kubectl proxy")
	if [ ! -z $PROXY_PID ]; then
		echo "Killing proxy PID $PROXY_PID"
		kill $PROXY_PID
	fi

	kubectl proxy >/dev/null 2>&1 &

	# copy the proxy pid

	sleep 10
	echo "Opening browser window for monitoring cluster"
	open http://localhost:8001/ui

fi