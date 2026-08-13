from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Application
    environment: str = "dev"

    # AWS
    aws_region: str = "eu-west-2"
    ingest_bucket: str

    # Database
    database_url: str

    model_config = SettingsConfigDict(
        env_file=".env",
    )


settings = Settings()

