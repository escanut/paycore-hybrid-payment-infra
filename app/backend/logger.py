import logging
import sys
from pythonjsonlogger import jsonlogger


# For docker container
stdout_handler = logging.StreamHandler(sys.stdout)
stdout_handler.setFormatter(jsonlogger.JsonFormatter("%(asctime)s %(levelname)s %(message)s"))

logging.basicConfig(
    level=logging.INFO,
    handlers=[stdout_handler]
)