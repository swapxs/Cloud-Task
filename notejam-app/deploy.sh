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

install_nginx() {
    printf "\nChecking for NGINX installation..."
    if ! command_exists nginx; then
        printf "\nNGINX not found. Installing..."
        sudo apt-get update
        sudo apt-get install -y nginx
    else
        printf "\nNGINX is already installed."
    fi
}

configure_reverse_proxy() {
    printf "\nConfiguring NGINX reverse proxy..."

    MINIKUBE_IP="$(minikube ip)"

    sudo tee /etc/nginx/sites-available/minikube.conf >/dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://$MINIKUBE_IP;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

    sudo ln -sf /etc/nginx/sites-available/minikube.conf /etc/nginx/sites-enabled/minikube.conf
    sudo rm /etc/nginx/sites-enabled/default
    sudo systemctl restart nginx
    printf "\nNGINX reverse proxy is configured to forward traffic from this server to http://$MINIKUBE_IP\n"
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

sudo mkdir /data/notejam-db/
sudo chown postgres:postgres /data/notejam-db/
sudo chmod 700 /data/notejam-db

kubectl apply -f manifests/ -n ${NAMESPACE}

printf "\nApplying Ingress..."
if ! kubectl apply -f manifests/ingress-manifest.yml -n ${NAMESPACE}; then
    kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found=true
    kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
    sleep 10
    kubectl apply -f manifests/ingress-manifest.yml -n ${NAMESPACE}
fi

printf "\nWaiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=notejam-db -n $NAMESPACE --timeout=600s

printf "\nWaiting for Notejam App to be ready..."
kubectl wait --for=condition=ready pod -l app=notejam-app -n $NAMESPACE --timeout=600s

printf "\nRunning database migrations..."
kubectl exec -n $NAMESPACE -it $(kubectl get pod -n $NAMESPACE -l app=notejam-app -o jsonpath="{.items[0].metadata.name}") -- python manage.py migrate

printf "\nUpdating /etc/hosts to access Notejam locally..."
printf "%s\t%s\n" "$(minikube ip)" "note.xenon.local" | sudo tee -a /etc/hosts

install_nginx
configure_reverse_proxy
printf "\n\nDeployment Completed Successfully!"
printf "\nAccess Notejam at: http://note.xenon.local\n"
