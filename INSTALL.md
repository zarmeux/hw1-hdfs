# Установка HDFS

## Требования

Четыре ВМ с Ubuntu 24.04 и доступом к репозиториям Ubuntu и архиву Apache. На edge нужны Bash, Python 3, curl и OpenSSH; Java 11 устанавливается скриптом. Пользователь `team` должен иметь `sudo` без пароля на всех узлах, а edge — SSH-доступ к внутренним узлам.

На стенде team-34 используются 2 vCPU, около 4 GiB RAM и 48 GiB диска на узел. NameNode получает heap 768 MiB, DataNode и SecondaryNameNode — по 512 MiB. Между узлами нужны TCP 9000, 9870, 9864, 9866, 9867 и 9868.

## Запуск установки

Разместите содержимое папки ДЗ на edge в `/home/team/hw1-hdfs`. Для другого стенда измените `cluster.env` либо создайте `cluster.local.env`:

| Параметр | Назначение |
|---|---|
| CONTROL_IP | edge, с которого запускается установка |
| NAMENODE_IP | NameNode |
| SECONDARY_IP | SecondaryNameNode, на отдельной от NameNode машине |
| DATANODE_IPS | три разных адреса DataNode |
| SSH_USER, SSH_KEY | доступ с edge на внутренние узлы |
| REMOTE_PROJECT | рабочая папка на внутренних узлах |
| HADOOP_VERSION, HADOOP_SHA512 | версия и контрольная сумма дистрибутива |

Запустите на edge:

```bash
cd /home/team/hw1-hdfs
bash scripts/deploy.sh
```

Скрипт скачивает дистрибутив, проверяет закреплённую SHA-512, распространяет его на узлы и устанавливает `openjdk-11-jdk-headless`. Hadoop работает под системным пользователем `hadoop`, без пароля и sudo. Установка завершается функциональной проверкой; ожидается `VERIFY_OK` и код 0. Логи подготовки узлов: `logs/setup-IP.log`.

## Сохранность данных

При наличии `namenode/current/VERSION` файловая система сохраняется. Форматирование выполняется только при пустом каталоге NameNode. Непустой каталог без VERSION или чужая установка Hadoop приводят к остановке скрипта.

Для изменения конфигурации действующего кластера сначала выполните `bash scripts/cluster.sh stop` с прежними параметрами, затем обновите конфигурацию и запустите deploy. Перенос метаданных NameNode между машинами выполняется отдельно.

Собственное имя каждого узла должно разрешаться во внутренний IP. Скрипт исправляет его привязку к `127.0.1.1` в `/etc/hosts`; исходный файл сохраняется в `/etc/hosts.hw1-backup`.

## Управление

На edge из папки ДЗ:

```bash
bash scripts/cluster.sh status
bash scripts/cluster.sh stop
bash scripts/cluster.sh start
```

| Назначение | Путь |
|---|---|
| Hadoop | `/opt/hadoop-3.4.2`, ссылка `/opt/hadoop` |
| Конфигурация | `/etc/hadoop` |
| Метаданные NameNode | `/var/lib/hadoop-hdfs/namenode` |
| Блоки DataNode | `/var/lib/hadoop-hdfs/datanode` |
| Контрольные точки | `/var/lib/hadoop-hdfs/secondary` |
| Логи | `/var/log/hadoop-hdfs` |

Службы: `hadoop-namenode`, `hadoop-datanode`, `hadoop-secondarynamenode`. При ошибке проверяйте `systemctl status` и соответствующий лог. `review.sh` проверяет действующий кластер; `verify.sh` дополнительно записывает новый тестовый файл. Последний также проверяет ERROR/FATAL в текущих логах: после перезапуска оценивайте сообщения вместе со временем и причиной остановки.

Ручные команды на NameNode:

```bash
sudo -u hadoop env HADOOP_CONF_DIR=/etc/hadoop /opt/hadoop/bin/hdfs dfsadmin -report
sudo -u hadoop env HADOOP_CONF_DIR=/etc/hadoop /opt/hadoop/bin/hdfs fsck / -files -blocks -locations
```

Документация: [Cluster Setup](https://hadoop.apache.org/docs/r3.4.2/hadoop-project-dist/hadoop-common/ClusterSetup.html), [HDFS User Guide](https://hadoop.apache.org/docs/r3.4.2/hadoop-project-dist/hadoop-hdfs/HdfsUserGuide.html).
