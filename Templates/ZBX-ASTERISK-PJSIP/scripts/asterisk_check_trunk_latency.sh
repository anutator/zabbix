#!/usr/bin/env bash
# "env" для совместимости с операционными системами BSD, где bash установлен в /usr/local/bin/bash в не /bin/bash
# Asterisk PJSIP Monitoring for Zabbix
# v1.0 -- Sebastien Bourgeois <sb@altho.st>
### Путь к исполняемому файлу бинарника Asterisk
ASTERISK=/usr/sbin/asterisk

if [ ! -n "$1" ]; then
    echo "Необходим аргумент."
    exit 1
fi
# pjsip show endpoints — отобразятся данные и по телефонам, и по транкам pjsip
# Поиск с помощью grep и egrep чувствителен к регистру, т.е. будет искать точное совпадение (параметр -i не используем)
# grep Contact — т.к. в данных по несколько строк, избавляемся от лишних. Оставляем только строки, содержащие слово Contact
# egrep -v "MaxContact|RTT\(ms\)" — расширенный поиск, параметр -v — наоборот исключаем строки, содержащие слова MaxContact или RTT(ms)
# так мы исключили две верхние строки с заголовками, оставив только список телефонов и транковых групп
# всего в строке 5 полей, разделенных пробелами. Это разделитель по умолчанию для awk (пробел или Tab), поэтому не надо указывать тип разделителя.
# Пример вида поля по, содержащего название транковой группы
# Здесь 380f121222 — третий столбец (хэш), Avail — четвертый столбец (статус), 26.321 — пятый столбейц.
# Contact:  belgorod/sip:10.112.3.9                    380f121222 Avail        26.321
# awk '{print $5} выводит пятый столбец — это RTT в миллисекундах.
$ASTERISK -rx "pjsip show endpoints"|grep Contact|egrep -v "MaxContact|RTT\(ms\)"|grep "$1"|awk '{print $5}'
