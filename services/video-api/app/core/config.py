from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    environment: str = 'dev'
    aws_region: str = 'eu-west-2'

    class Config:
        env_file = '.env'

settings = Settings()

