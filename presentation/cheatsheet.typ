= Деплой приложения на сервер

+ 1 шаг. Собираем образ

  ```sh
  docker build -t aboba-app:0.1 .
  ```

+ 2 шаг. Сохраняем образ в файл

  ```sh
  docker save aboba-app:0.1 > aboba-app.tar
  ```

+ 3 шаг. Загружаем файл образа на сервер

  ```sh
  scp ./aboba-app.tar user@server:/path/to/destination
  ```

+ 4 шаг. Подключаемся к серверу

  ```sh
  ssh user@server
  ```

+ 5 шаг. Загружаем образ из файла

  ```sh
  docker load < aboba-app.tar
  ```

+ 6 шаг. Копируем docker-compose (прописав в него название образа,
  загруженного из файла). И запускаемся:

  ```sh
  nvim docker-compose.yaml
  docker compose up -d
  ```

+ 7 шаг. Поздравляем! Мы запустились! Теперь можем проверить, что
  всё работает, с компьютера клиента

  ```sh
  curl http://server:port/products
  ```

= Эксперименты над Dockerfile'ом сервиса на Go

+ Для начала втупую скопируем все файлы проекта, после чего запустим
  процесс компиляции.

  ```Dockerfile
  FROM golang:1.23-alpine as builder

  WORKDIR /app
  COPY . .
  RUN go build -o ./main main.go

  FROM alpine:3.20
  COPY --from=builder /app/main /app/main

  ENTRYPOINT ["/app/main"]
  ```

+ Попробуем собрать наш образ

  ```sh
  docker compose build app
  ```

+ Всё хорошо, но давайте теперь модифицируем наш код

  ```sh
  nvim main.go
  ```

+ Попробуем собрать наш образ ещё раз

  ```sh
  docker compose build app
  ```

  Как мы можем заметить, наши зависимости начали скачиваться
  заново.

+ Теперь напишем наш Dockerfile по-другому

  ```Dockerfile
  FROM golang:1.23-alpine as builder

  WORKDIR /app
  COPY go.mod go.sum .
  RUN go mod download

  COPY . .
  RUN go build -o ./main main.go

  FROM alpine:3.20
  COPY --from=builder /app/main /app/main

  ENTRYPOINT ["/app/main"]
  ```

+ Соберём

  ```sh
  docker compose build app
  ```

+ Попробуем снова модифицировать наш код

  ```sh
  nvim main.go
  ```

+ И опять соберём образ

  ```sh
  docker compose build app
  ```

  Теперь мы не скачиваем зависимости заново


= Разница между shell- и exec-режимами

Если мы взглянем на Dockerfile питоновского проекта из первой части,
то мы увидим очень интересную конструкцию `CMD`, где каждое слово
в команде пишется в кавычках, а между ними ставится запятая.

```Dockerfile
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Но разве нельзя просто записать команду строкой? На самом деле можно.
Давайте так и сделаем.

```Dockerfile
CMD uvicorn main:app --host 0.0.0.0 --port 8000
```

Выглядит лаконично, но есть нюанс.

Давайте для простоты сделаем специальный Dockerfile, на котором мы
посмотрим разницу между shell- и exec-режимами.

```Dockerfile
FROM alpine:3.20
CMD ["ping", "ya.ru"]
```

Запустим контейнер и выполним команду `ps` внутри него:

```sh
docker build -t aboba:1.0 .
docker run aboba:1.0
docker ps  # Смотрим ID контейнера
docker exec <ID-контейнера> ps
```

```
PID   USER     TIME  COMMAND
    1 root      0:00 ping ya.ru
    6 root      0:00 ps
```

Мы наблюдаем 2 процесса. Один процесс -- это команда `ps`. Он тут есть
в целом по понятным причинам. А вот другой процесс -- это команда `ping`,
которую мы прописали в Dockerfile. Поскольку `ps` обычно отрабатывает
и завершает свою работу, фактически в нашем контейнере работает только
один процесс -- `ping`. Более того, он имеет PID = 1. Этот факт нам
понадобится дальше, когда мы перепишем Dockerfile в shell-режиме:

```Dockerfile
FROM alpine:3.20
CMD ping ya.ru
```

Давайте теперь соберём и запустим наш контейнер:

```sh
docker build -t aboba:2.0 .
docker run aboba:2.0
docker ps  # Смотрим ID контейнера
docker exec <ID-контейнера> ps
```

И получим... Тоже самое?

```
PID   USER     TIME  COMMAND
    1 root      0:00 ping ya.ru
    7 root      0:00 ps
```

Окей. А тогда в чём же разница? Давайте попробуем заменить Alpine
на Debian:

```Dockerfile
FROM debian:12.9
RUN apt-get update -y
RUN apt-get install -y iputils-ping
RUN apt-get install -y procps
CMD ping ya.ru
```

Собираем и запускаем:

```sh
docker build -t aboba:2.0 .
docker run aboba:2.0
docker ps  # Смотрим ID контейнера

# Введём флаг -ef, чтобы видеть ID родительнского процесса (PPID)
docker exec <ID-контейнера> ps -ef
```

А вот тут уже есть какие-то различия в списке процессов:

```
UID          PID    PPID  C STIME TTY          TIME CMD
root           1       0  0 05:28 ?        00:00:00 /bin/sh -c ping ya.ru
root           7       1  0 05:28 ?        00:00:00 ping ya.ru
root          20       0 75 05:29 ?        00:00:00 ps -ef
```

Что мы видим?
+ Процессом с PID = 1 является `/bin/sh`, а не `ping`.
+ `ping` имеет PID равный 7.
+ Кроме того, его PPID равен 1, а это значит, что `/bin/sh`
  является родительским процессом для `ping`.

Что же будет, если мы попробуем остановить контейнер, послав
сигнал `SIGINT` при помощи Ctrl+C?

+ Контейнер, созданный из образа `aboba` будет завершён.
+ Контейнер, созданный из образа `aboba2` аналогично.
+ А вот `aboba3` будет игнорировать наши попытки его завершить
  (именно так и начинается Skynet).

Чтобы понять, в чём разница, мы взглянем на вывод команды
`docker inspect aboba` и `docker inspect aboba3`. Эти команда
нам распечатают JSON, в котором содержится метаинформация
про наши образы. Там много любопытной информации, проливающей
свет на то, как Docker устроен, но нас интересуют конкретные
несколько строк:

+ ```sh
  docker inspect aboba
  ```

  ```json
  [
    {
      ...
      "Config": {
        ...
        "Cmd": ["ping", "ya.ru"],
        ...
      }
      ...
    }
  ]
  ```

+ ```sh
  docker inspect aboba3
  ```

  ```json
  [
    {
      ...
      "Config": {
        ...
        "Cmd": ["/bin/sh", "-c", "ping ya.ru"],
        ...
      }
      ...
    }
  ]
  ```

Как мы можем наблюдать, у нас по-разному запускается наш `ping`.
В первом случае он запускается напрямую. Во втором же случае
он запускается через `/bin/sh`. Собственно поэтому он и является
родительским процессом для `ping`. И именно поэтому сигналы
до процесса `ping` не доходят, ведь в Docker'е сигналы, посланные
контейнеру, всегда идут до процесса с PID = 1, которым в `aboba3`
является `/bin/sh`.

Но что же с `aboba2`? Давайте тоже для него запустим
`docker inspect aboba2`:

```json
[
  {
    ...
    "Config": {
      ...
      "Cmd": ["/bin/sh", "-c", "ping ya.ru"],
      ...
    }
    ...
  }
]
```

И мы получаем то же самое... Но почему же мы получаем то же
поведение, что и у `aboba`? Я задался таким же вопросом, когда
готовился к этой лекции. Для изучения этой темы я решил воспользоваться
статьёй на Хабер за 2017 год: https://habr.com/ru/companies/slurm/articles/329138/

Сама по себе статья хорошая, однако, она оказалось немного неактуальной
для новых версий Alpine. Дело в том, что Alpine вместо стандартного
пакета GNU Coreutils использует BusyBox. При чём, видимо модифицированный,
поскольку в других дистрибутивах, где используется BusyBox, поведение
`sh` было больше похоже на образ `aboba3`. Скорее всего, разработчики
Alpine, нацеленные на пользователей Docker, решили модифицировать
оболочку командной строки, чтобы она не имела тех багов, которые
возникают с `aboba3`.

Тем не менее, несмотря на то, что в Alpine shell-форма не имеет
тех багов, которые есть в Debian, всё же разработчики Docker рекомендуют
использовать exec-форму.

= Разница между CMD и ENTRYPOINT

+ `CMD` определяет команду, которая будет выполнена при запуске, контейнера.

  ```Dockerfile
  FROM alpine:3.20
  CMD ["echo", "Hello, World!"]
  ```

  ```sh
  $ docker build -t hello-world-image:1.0 .
  $ docker run hello-world-image:1.0
  Hello, world!
  ```

  При этом мы можем спокойно переопределить команду, которая будет выполнена,
  при запуске контейнера:

  ```sh
  $ docker run hello-world-image:1.0 echo "Aboba"
  Aboba
  ```

+ `ENTRYPOINT` определяет команду, которая будет выполнена при запуске
  контейнера.

  ```Dockerfile
  FROM alpine:3.20
  ENTRYPOINT ["echo", "Hello, World!"]
  ```

  ```sh
  $ docker build -t hello-world-image:2.0 .
  $ docker run hello-world-image:2.0
  Hello, world!
  ```

  Казалось бы, то же самое. Однако различия появляются, когда мы добавим
  аргументы:

  ```sh
  $ docker run hello-world-image:2.0 echo "Aboba"
  Hello, World! echo Aboba
  ```

  Как мы видим, при использовании `ENTRYPOINT` переопределяется
  не вся команда, а только её аргументы. Это может быть удобно,
  если ваша программа принимает какие-либо аргументы.

  При этом мы всё ещё можем переопределить команду, которая будет
  выполнена при запуске контейнера, используя флаг `--entrypoint`:

  ```sh
  docker run --entrypoint ps hello-world-image:2.0
  ```

  ```
  PID   USER     TIME  COMMAND
      1 root      0:00 ps
  ```

+ `ENTRYPOINT` + `CMD`

  Мы можем использовать `CMD` для указания аргументов по умолчанию,
  которые будут переданы в `ENTRYPOINT`:

  ```Dockerfile
  FROM alpine:3.20
  ENTRYPOINT ["echo"]
  CMD ["Hello, world!"]
  ```

  В таком случае по-умолчанию команде `echo` в качестве аргумента
  будет передаваться строка `Hello, world!`. Однако, если мы укажем
  другой аргумент, он заменить аргумент, прописанный `CMD`.

  ```sh
  $ docker build -t hello-world-image:3.0 .
  $ docker run hello-world-image:3.0
  Hello, world!
  $ docker run hello-world-image:3.0 Aboba
  Aboba
  ```

= Конфигурирование приложений в Docker при помощи переменных окружения

Одним из самых частых способов для конфигурации приложения является
использование переменных окружения. Давайте напишем небольшой проект
на Python, который будет считывать переменные окружения `DB_URL` и `API_KEY`
выводить их на экран. Для управления зависимостями мы будем использовать `uv`.

```sh
uv init example1
cd example1
uv add pydantic pydantic-settings python-dotenv
```

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from time import sleep


class Settings(BaseSettings):
    db_url: str
    api_key: str

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


def main():
    settings = Settings()
    print(settings, flush=True)

    while True:
        sleep(1)


if __name__ == "__main__":
    main()
```

Здесь мы использовали библиотеки `pydantic` и `python-dotenv`. Первая
позволяет производить валидацию нашей конфигурации, а вторая позволяет
записывать значения переменных окружения из файла `.env`. Как правило,
это делается для удобства разработчика, чтобы ему не пришлось постоянно
вводить эти переменные в терминале. Впрочем, если `.env` файла нет,
`python-dotenv` будет считывать значения, что называется, "по-старинке"
из непосредственно переменных окружения. Этот факт нам пригодится позже.

Напишем Dockerfile для нашего приложения (данный файл можно улучшить,
но это мы рассмотрим позже):

```Dockerfile
FROM python:3.13-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
ADD . /app
WORKDIR /app
RUN ["uv", "sync", "--frozen"]
CMD ["uv", "run", "main.py"]
```

Теперь напишем .env файл:

```sh
DB_URL=aboba
API_KEY=aboba
```

Соберём и запустим наш образ:

```sh
docker build -t config-example:1.0 .
docker run config-example:1.0
```

Что ж, наше приложение работает!

```
db_url='aboba' api_key='aboba'
```

Однако есть несколько проблем:
+ Мы в образ копируем директорию .venv, которая создана на хостовой машине.
  Это проблема по двум причинам:
  + Операционная система на хостовой машине и в контейнере могут отличаться.
    А поскольку помимо зависимостей на Python у нас могут быть и бинарные
    зависимости, это может привести к проблемам. (Впрочем, если мы посмотрим
    внимательно на логи, `uv` автоматически удаляет случайно скопированное
    нами виртуальное окружение и создаёт своё. Но так происходит не всегда,
    особенно если не использовать `uv`).
  + `.venv` может весить очень много (например, в больших проектах или проектах,
    использующих ML-библиотеки) => копирование будет происходить долго. Мы
    просто тратим время на операции, которые нам не нужны. В любом случае,
    нам нужно создавать своё виртуальное окружение для образа.
+ Также мы копируем `.env` файл в наш образ. Это уже проблема в безопасности.
  В образе не должны храниться секреты, по типу паролей, API-ключей и прочего,
  так как в случае утечки образа (или если ваш образ общедоступный) ваши
  секреты будут скомпрометированы, не говоря уже о том, что мы не сможем
  по-разному конфигурировать контейнеры, запускаемые из этого образа.
+ Мы копируем кэш-файлы и папки, по типу `__pycache__`. Как и `.venv`, кэши
  являются платформозависимыми и не должны быть включены в образ по тем же
  причинам.
+ Если вы используете Git и директория `.git` находится в корне проекта, то
  она тоже будет копироваться, увеличивая размер образа, хотя для сборки
  образа она как правило не нужна.

Мы бы могли модифицировать команду `ADD` в Dockerfile, например, используя
регулярные выражения или вручную прописав все необходимые для копирования
файлы. Но есть более удобный способ исключить из копирования ненужные файлы
-- `.dockerignore` файл. Он работает аналогично тому, как работает `.gitignore`.
В `.dockerignore` файле можно указать паттерны файлов и директорий, которые не
должны быть скопированы в образ. Создадим `.dockerignore` файл в корне проекта:

```.gitignore
.git
.venv
__pycache__
.env
```

Давайте снова соберём и запустим наш образ:

```sh
docker build -t config-example:2.0 .
docker run config-example:2.0
```

И теперь наше приложение не работает:

```
...
pydantic_core._pydantic_core.ValidationError: 2 validation errors for Settings
db_url
  Field required [type=missing, input_value={}, input_type=dict]
    For further information visit https://errors.pydantic.dev/2.10/v/missing
api_key
  Field required [type=missing, input_value={}, input_type=dict]
    For further information visit https://errors.pydantic.dev/2.10/v/missing
```

Очевидно, это происходит, потому что `.env` файл не был скопирован в образ.
Как вы помните, если `python-dotenv` не находит `.env` файл, то он просто
считывает параметры из переменных окружения. Но как установить переменные
окружения при запуске образа? Мы бы могли использовать команды `Dockerfile`:

```Dockerfile
ENV DB_URL=aboba
ENV API_KEY=aboba
```

Но тогда мы не решаем проблему с тем, что в случае утечки образа наши секреты
будут скомпрометированы. Вместо этого мы воспользуемся флагом `-e` при запуске
образа:

```sh
docker run -e DB_URL=aboba -e API_KEY=aboba config-example:2.0
```

Теперь наше приложение работает!

```
db_url='aboba' api_key='aboba'
```

== Docker compose

Давайте теперь посмотрим, как передавать конфигурацию в контейнер при использовании
docker compose:

```yaml
services:
  app:
    image: my-app:latest
    environment:
      DB_URL: aboba
      API_KEY: aboba
```

Запустим наше приложение и посмотрим, как оно работает:

```sh
docker compose up
```

И... Всё работает!

```
...
[+] Running 3/3
 ✔ app                       Built                                                                                                                 0.0s
 ✔ Network example1_default  Created                                                                                                               0.2s
 ✔ Container example1-app-1  Created                                                                                                               0.1s
Attaching to app-1
app-1  | db_url='aboba' api_key='aboba'
```

Если ваш docker compose файл хранится в репозитории вместе с проектом,
в нём тоже очень нежелательно хранить секреты. Благо, docker compose
также позволяет прописывать переменные окружения при запуске команды:

```yaml
services:
  app:
    build: .
    environment:
      DB_URL: ${DB_URL}
      API_KEY: ${API_KEY}
```

```sh
DB_URL=aboba API_KEY=pupupu docker compose up
```

```
[+] Running 1/1
 ✔ Container example1-app-1  Created                                                                                                        0.0s
Attaching to app-1
app-1  | db_url='aboba' api_key='pupupu'
```

Если же вы попробуете запустить приложение с указанием переменных
окружения, но используя первый docker compose файл, то ничего не поменяется.

Помимо того, что мы можем напрямую прописать переменные окружения,
docker compose может считывать их из файла `.env`.

Модифицируем `.env` файл:

```sh
DB_URL=csit
API_KEY=sgu
```

Потом напишем новый docker compose файл:

```yaml
services:
  app:
    build: .
    env_file: .env
```

Запустим приложение:

```sh
docker compose up
```

```
[+] Running 1/1
 ✔ Container example1-app-1  Recreated                                                                                                      0.1s
Attaching to app-1
app-1  | db_url='csit' api_key='sgu'
```

*Важно! Из .env файла считывает переменные окружения не наш проект, а docker compose.
После считывания он их записывает в переменные окружения контейнера, из которых
параметры уже берёт наше приложение. Никакого .env файла (если вы прописали .dockerignore
файл по инструкции ниже, в образе или контейнере нет)*

```sh
$ docker ps  # Смотрим ID контейнера
$ docker exec <ID контейнера> ls -a
..
.dockerignore
.python-version
.venv
Dockerfile
README.md
docker-compose.yaml
main.py
pyproject.toml
uv.lock
```

_Кстати, в наш .gitignore можно добавить README.md, Dockerfile и docker-compose.yaml.
Для функционирования приложения внутри контейнера они не нужны. При этом директория .venv
была создана uv при сборке образа, поэтому она тут есть, несмотря на то, что она прописана
в .dockerignore._
