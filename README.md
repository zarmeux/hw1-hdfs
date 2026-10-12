# ДЗ №1 — развёртывание HDFS

Мы развернули HDFS на четырёх виртуальных машинах команды team-34: один NameNode, один SecondaryNameNode и три DataNode. Установку сделали через Bash-скрипты, а порядок действий описали в [INSTALL.md](INSTALL.md).

## Как устроен кластер

На всех машинах используем Ubuntu 24.04, OpenJDK 11 и Hadoop 3.4.2. У каждой ВМ по 2 vCPU, около 4 GiB памяти и 48 GiB диска.

| Машина | Внутренний IP | Роль |
|---|---|---|
| team-34-en | 10.34.0.10 | edge, SecondaryNameNode |
| team-34-nn | 10.34.0.11 | NameNode, DataNode |
| team-34-00 | 10.34.0.12 | DataNode |
| team-34-01 | 10.34.0.13 | DataNode |

К edge подключаемся по внешнему адресу `111.88.130.214`. Остальные машины доступны через него по SSH.

NameNode и один DataNode мы разместили на одной ВМ: так на четырёх машинах получилось три узла хранения, а SecondaryNameNode остался на отдельном узле. Он создаёт контрольные точки метаданных, но не заменяет NameNode при отказе.

## Установка

На edge из папки `/home/team/hw1-hdfs`:

```bash
bash scripts/deploy.sh
```

Скрипт скачивает Hadoop, проверяет SHA-512, устанавливает Java и настраивает все узлы. Для демонов мы создали отдельного пользователя `hadoop`. Службы работают через systemd и включены в автозапуск.

Основные пути:

| Что | Где |
|---|---|
| Hadoop | `/opt/hadoop-3.4.2`, ссылка `/opt/hadoop` |
| Конфигурация | `/etc/hadoop` |
| Метаданные NameNode | `/var/lib/hadoop-hdfs/namenode` |
| Блоки DataNode | `/var/lib/hadoop-hdfs/datanode` |
| Контрольные точки | `/var/lib/hadoop-hdfs/secondary` |
| Логи | `/var/log/hadoop-hdfs` |

В `core-site.xml` мы указали `fs.defaultFS=hdfs://10.34.0.11:9000`, а в `hdfs-site.xml` — репликацию 3, адреса служб и каталоги хранения. Параметры стенда находятся в [cluster.env](cluster.env). Для другого стенда их можно переопределить в `cluster.local.env`.

Форматирование NameNode выполняется только при пустом каталоге. Если есть `current/VERSION`, скрипт сохраняет существующую файловую систему. Непустой каталог без этого файла вызывает остановку установки.

## Что мы проверили

После установки мы записали тестовый файл в HDFS, прочитали его обратно и сравнили содержимое. Затем повторно запустили установку: namespace и уже записанный файл сохранились.

Проверки показали:

- три DataNode работают и находятся в обслуживании; dead и stale узлов нет;
- safe mode выключен;
- у тестовых файлов по три реплики на разных DataNode;
- полный `fsck` возвращает `HEALTHY`: потерянных, повреждённых и недореплицированных блоков нет;
- SecondaryNameNode создаёт непустые `fsimage`;
- при функциональной проверке в логах HDFS не было сообщений ERROR/FATAL.

![Три работающих DataNode](evidence/datanodes.png)

Тестовые файлы оставили в HDFS:

```text
/hw1-check/check-20261011T160449Z-18950.txt
/hw1-check/check-20261011T160737Z-29479.txt
```

Вывод команд сохранили в [verification.txt](evidence/verification.txt). Повторное развёртывание описано в [idempotence.txt](evidence/idempotence.txt), работа SecondaryNameNode — в [secondary-checkpoint.txt](evidence/secondary-checkpoint.txt). Дополнительная проверка 11.10.2026 в 20:14 МСК завершилась `REVIEW_OK`: [review.txt](evidence/review.txt).

## Что пришлось исправить

Сначала собственные имена машин разрешались в `127.0.1.1`. Из-за этого Hadoop мог использовать loopback вместо внутреннего адреса. Мы исправили привязку имён к IP сети `10.34.0.0/24` и добавили это исправление в `node-setup.sh`. Исходный `/etc/hosts` сохраняется в `/etc/hosts.hw1-backup`.

## Файлы работы

- [INSTALL.md](INSTALL.md) — требования, установка и управление кластером.
- [scripts/](scripts/) — скрипты установки и проверок.
- [evidence/REPORT.md](evidence/REPORT.md) — результаты проверки.
- [ДЗ №2 — YARN и веб-интерфейсы](https://github.com/zarmeux/hw2-yarn).
- [Условие задания](https://go.teachbase.ru/education/listener/course_player/sessions/1415858/tasks/412727).
