#!/bin/sh
set -e
set -o nounset

NAMESPACE="notejam"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_kubectl() {
    printf "\nInstalling kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
}

install_minikube() {
    printf "\nInstalling minikube..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
}

if ! command_exists kubectl; then
    install_kubectl
else
    printf "\nkubectl is already installed."
fi

if ! command_exists minikube; then
    install_minikube
else
    printf "\nminikube is already installed."
fi

if minikube status >/dev/null 2>&1; then
    printf "\nStopping and deleting existing Minikube instance..."
    minikube stop
    minikube delete
fi

minikube start
minikube addons enable ingress

kubectl wait --namespace kube-system --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx --timeout=600s || {
    printf "\nIngress Controller is not ready. Restarting Ingress..."
    minikube addons disable ingress
    minikube addons enable ingress
}

kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found=true
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx

if ! kubectl create namespace ${NAMESPACE} 2>/dev/null; then
    printf "\nNamespace already exists."
fi

kubectl apply -f notejam-configmap.yml -n ${NAMESPACE}
kubectl apply -f notejam-secret.yml -n ${NAMESPACE}
kubectl apply -f notejam-pv.yml -n ${NAMESPACE}
kubectl apply -f notejam-db-statefulset.yml -n ${NAMESPACE}
kubectl apply -f notejam-app-deployment.yml -n ${NAMESPACE}
kubectl apply -f notejam-app-service.yml -n ${NAMESPACE}

printf "\nApplying Ingress..."
if ! kubectl apply -f notejam-ingress.yml -n ${NAMESPACE}; then
    kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found=true
    kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
    sleep 10
    kubectl apply -f notejam-ingress.yml -n ${NAMESPACE}
fi

printf "\nWaiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=notejam-db -n $NAMESPACE --timeout=600s

printf "\nWaiting for Notejam App to be ready..."
kubectl wait --for=condition=ready pod -l app=notejam-app -n $NAMESPACE --timeout=600s

printf "\nRunning database migrations..."
kubectl exec -n $NAMESPACE -it $(kubectl get pod -n $NAMESPACE -l app=notejam-app -o jsonpath="{.items[0].metadata.name}") -- python manage.py migrate

printf "\nUpdating /etc/hosts to access Notejam locally..."
printf "%s\t%s\n" "$(minikube ip)" "note.xenon.local" | sudo tee -a /etc/hosts

printf "\n\nDeployment Completed Successfully!"
printf "\nAccess Notejam at: http://note.xenon.local\n"
