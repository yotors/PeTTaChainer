import uvicorn


def run() -> None:
    uvicorn.run("pettachainer.server.app:app", host="0.0.0.0", port=8000, proxy_headers=False)


if __name__ == "__main__":
    run()
