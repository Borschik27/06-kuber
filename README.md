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
