from fastapi import FastAPI
from pydantic import BaseModel
import json
import os

app = FastAPI()

DATA_FILE = "/data/people.json"


def read_people():
    if os.path.exists(DATA_FILE):
        with open(DATA_FILE, "r") as f:
            return json.load(f)
    return []


def write_people(people):
    with open(DATA_FILE, "w") as f:
        json.dump(people, f)


class Person(BaseModel):
    name: str
    age: int


@app.get("/people")
def get_people():
    people = read_people()
    return people


@app.post("/people")
def add_person(person: Person):
    people = read_people()
    people.append(person.dict())
    write_people(people)
    return {"message": "Person added successfully"}
