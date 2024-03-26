import json
import os
import urllib.request

import boto3

client = boto3.client("secretsmanager")

response = client.get_secret_value(
    SecretId=os.environ["MY_APP_SECRETS_NAME"],
)

OPENAI_API_KEY = response["SecretString"]


def lambda_handler(event, context):
    body = {
        "model": "gpt-3.5-turbo",
        "messages": [
            {
                "role": "system",
                "content": "You will be provided with a piece of code, and your task is to explain it in a concise way.",
            },
            {
                "role": "user",
                "content": event["body"],
            },
        ],
        "temperature": 0.7,
        "max_tokens": 64,
        "top_p": 1,
    }

    request = urllib.request.Request("https://api.openai.com/v1/chat/completions")
    request.add_header("Content-Type", "application/json; charset=utf-8")
    request.add_header("Authorization", f"Bearer {OPENAI_API_KEY}")

    response = urllib.request.urlopen(request, json.dumps(body).encode())
    
    data = json.loads(response.read())

    return {"statusCode": 200, "body": data["choices"][0]["message"]["content"]}
