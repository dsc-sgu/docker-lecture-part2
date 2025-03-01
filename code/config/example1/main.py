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
