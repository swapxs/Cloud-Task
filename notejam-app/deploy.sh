#!/bin/sh
set -e
set -o nounset

NAMESPACE="notejam"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if ! command_exists kubectl; then
  printf "\nkubectl not found. Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  printf "\nkubectl is already installed."
fi

if ! command_exists minikube; then
  printf "\nminikube not found. Installing minikube..."
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
else
  printf "\nminikube is already installed."
fi

if minikube status >/dev/null 2>&1; then
  printf "\nAn existing minikube instance was found. Stopping and deleting the current minikube instance..."
  minikube stop
  minikube delete
fi

minikube start
minikube addons enable ingress

if ! kubectl create namespace notejam 2>/dev/null; then
    printf "\nNamespace 'notejam' already exists."
fi

printf "\napplying manifest\n"
kubectl apply -f notejam-configmap.yml -n ${NAMESPACE}
kubectl apply -f notejam-secret.yml -n ${NAMESPACE}
kubectl apply -f notejam-pv.yml -n ${NAMESPACE}
kubectl apply -f notejam-db-statefulset.yml -n ${NAMESPACE}
kubectl apply -f notejam-app-deployment.yml -n ${NAMESPACE}
kubectl apply -f notejam-app-service.yml -n ${NAMESPACE}
kubectl apply -f notejam-ingress.yml -n ${NAMESPACE}

printf "\n\nStatus\n"
kubectl wait --for=condition=ready pod -l app=notejam-app -n $NAMESPACE --timeout=120s
kubectl exec -n $NAMESPACE -it $(kubectl get pod -n $NAMESPACE -l app=notejam-app -o jsonpath="{.items[0].metadata.name}") -- python manage.py migrate --fake-initial
printf "%s\t%s\n" "$(minikube ip)" "notejam.local" | sudo tee -a /etc/hosts
