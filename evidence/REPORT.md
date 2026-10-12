# HDFS: результаты проверки

Стенд team-34, 11.10.2026. Первичная функциональная проверка — около 19:09 МСК; повторная проверка состояния — 20:14 МСК. В выводе команд время указано в UTC.

| Проверка | Результат |
|---|---|
| NameNode, SecondaryNameNode, три DataNode | active / enabled |
| Live / in service / dead / stale DataNode | 3 / 3 / 0 / 0 |
| Ошибки томов, недореплицированные и ожидающие репликации блоки | 0 |
| Safe mode | OFF |
| Запись и чтение | содержимое совпало |
| Репликация тестовых блоков | Live_repl=3 |
| Полный fsck | HEALTHY, потерянных и повреждённых блоков нет |
| SecondaryNameNode | созданы непустые fsimage |
| Повторный deploy | namespace и ранее записанный файл сохранены |

- [review.txt](review.txt) — свежая проверка действующих служб и данных, `REVIEW_OK`.
- [verification.txt](verification.txt) — функциональная проверка, `VERIFY_OK`.
- [idempotence.txt](idempotence.txt) — идентификаторы namespace, хеш сохранённого файла, состояние `/etc/hosts` после повторной установки.
- [namenode-state.json](namenode-state.json) — снимок метрик при функциональной проверке.
- [secondary-checkpoint.txt](secondary-checkpoint.txt) — checkpoint, служба и автозапуск.
- [datanodes.png](datanodes.png) — интерфейс NameNode.

Тестовые файлы:

```text
/hw1-check/check-20261011T160449Z-18950.txt
/hw1-check/check-20261011T160737Z-29479.txt
```

Оба файла имеют по три реплики. SHA-256 содержимого каждого: `690525c05aed9d76c9f86711da3eb85e2af7521cb06078588656595d67d9e3fa`.

Проверка текущего состояния выполнена скриптом `scripts/review.sh`; запись и чтение проверены скриптом `scripts/verify.sh`.
