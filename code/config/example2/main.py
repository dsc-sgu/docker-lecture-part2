import json
from pydantic import BaseModel
from time import sleep


class Settings(BaseModel):
    db_url: str
    api_key: str

    @classmethod
    def from_json(cls, file_path: str):
        with open(file_path, 'r') as f:
            data = json.load(f)
        return cls(**data)


def main():
    settings = Settings.from_json('/config/settings.json')
    print(settings, flush=True)

    while True:
        sleep(1)


if __name__ == "__main__":
    main()
