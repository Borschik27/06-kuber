# 06-kuber

Для выполнения этого задания и последующий в связи с высокой нагрузкой на рабочий кластер, приведу пример создания
кластера с нуля на YC-машинах не испоьзуя возможность поднятия кластера с помощью сервисов YC

Проект terraform + ansible раскатает три виртальных машины в облаке и настроить их систему по минимальной конфигурации
Проект приложен

1. После настройки внесем адреса хостов в файл /etc/hosts
2. Создадим минимальный init-конфиг для kubeadm и мигрируем его под актуальный

```
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: <control-panel-add>
  bindPort: 6443

---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
networking:
  podSubnet: 192.168.240.0/24
  serviceSubnet: 10.96.0.0/24
  dnsDomain: cluster.local
controlPlaneEndpoint: <control-panel-addr:port>
```

И мигрирует в актуальный с помощью команды:

```
kubeadm config migrate --old-config <path-to-old.yaml> --new-config <path-to-new.yaml>
```

После создания конфиг файла можно загрузить образы для проверки коректности:
```
kubeadm config images pull
```

Проверим что конфиг правильный:
```
sudo kubeadm init --config=<path-init.yaml> --dry-run
```

Инициализируем кластер:
```
sudo kubeadm init --config=<path-init.yaml>
```

Вывод предложит нам настройку для использования кластера от регуляного пользователя, а так же команду для присоединения узлов к кластеру.

После чего заходим на воркеры и вводим команду для присоединения кластера:
```
kubeadm join 10.1.1.31:6443 --token pn.....na8 \
        --discovery-token-ca-cert-hash sha256:dc4b.....bfcd77a
```

---
Примичания:
Токен действует 24 часа, создания нового токена:
```
kubeadm token list
sudo kubeadm token create --ttl=24h --description="Node join token"
```

Что бы достать hash:
```
 openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'

```
---

Снимим taint:
```
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

Установим k9s для упращения работы с кластером, скачаем deb-пакет и установим:
```
Найдем тут:
https://github.com/derailed/k9s/releases

Установим так:
dpkg -i <package-name>
```

Видно что узлы добавлены и часть подов работает:
![image](https://github.com/user-attachments/assets/cf04a820-0471-4679-a90a-0c3412b6bb6e)

Статус pending потому что не установлен CNI
Для примера возьмем CALICO:
```
Get manifest:
curl -fLO https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml
```

---
Примеания: 
По умолчанию CALICO как и другие CNI плагины могу использовать сторонюю сеть для подов проверяйте манулы к плагину
Найти можно в манифесте:
```
- name: CALICO_IPV4POOL_CIDR
  value: "192.168.240.0/24"
```

Так же возможна проблема с выбором интерфейсо которые будет использовать CALICO для подов, для этого требуется добавить настройку которая укажет какие интерфейсы использовать (такая проблема может возникнуть если на выших узлах тесколько сетевых карт eth/infiniband/oth.):
```
- name: IP_AUTODETECTION_METHOD
  value: "interface=^en.*"
```
---

Применим CALICO:
```
kubectl apply -f calico.yaml
poddisruptionbudget.policy/calico-kube-controllers created
serviceaccount/calico-kube-controllers created
serviceaccount/calico-node created
serviceaccount/calico-cni-plugin created
configmap/calico-config created
customresourcedefinition.apiextensions.k8s.io/bgpconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgpfilters.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgppeers.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/blockaffinities.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/caliconodestatuses.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/clusterinformations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/felixconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/hostendpoints.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamblocks.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamconfigs.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamhandles.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ippools.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipreservations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/kubecontrollersconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/tiers.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/adminnetworkpolicies.policy.networking.k8s.io created
customresourcedefinition.apiextensions.k8s.io/baselineadminnetworkpolicies.policy.networking.k8s.io created
clusterrole.rbac.authorization.k8s.io/calico-kube-controllers created
clusterrole.rbac.authorization.k8s.io/calico-node created
clusterrole.rbac.authorization.k8s.io/calico-cni-plugin created
clusterrolebinding.rbac.authorization.k8s.io/calico-kube-controllers created
clusterrolebinding.rbac.authorization.k8s.io/calico-node created
clusterrolebinding.rbac.authorization.k8s.io/calico-cni-plugin created
daemonset.apps/calico-node created
deployment.apps/calico-kube-controllers created
```
![image](https://github.com/user-attachments/assets/aae63b52-f66b-45cb-9f8c-8eb8c9dc8544)

Накатим LoadBalancer, возьмем metallb:
```
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
```

Создадим configmap для metallb:
```
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: fast-pool
  namespace: metallb-system
spec:
  addresses:
# Use solo address
#  - 192.168.16.144/32
# Use range
  - 10.1.1.10-10.1.1.15

---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: fast
  namespace: metallb-system
spec:
  ipAddressPools:
  - fast-pool
```
