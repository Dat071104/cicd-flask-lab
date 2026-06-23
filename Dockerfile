FROM python:3.12-alpine

WORKDIR /app

# Create non-root user (Alpine uses addgroup/adduser)
RUN addgroup -g 1000 appuser && \
    adduser -u 1000 -G appuser -D -h /app appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 5000

CMD ["python", "app.py"]
