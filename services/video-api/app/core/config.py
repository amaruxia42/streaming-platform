from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    environment: str = "dev"
    aws_region: str = "eu-west-2"

    ingest_bucket: str

    model_config = SettingsConfigDict(
        env_file=".env"
    )


settings = Settings()

