FROM python:3.11-slim
WORKDIR /app
COPY scaling_rule.py autoscaler.py ./
CMD ["python", "-u", "autoscaler.py"]
