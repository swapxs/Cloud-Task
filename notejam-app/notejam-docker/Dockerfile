FROM python:2.7
ENV PYTHONUNBUFFERED=1
WORKDIR /app/notejam
COPY . /app/
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install psycopg2
EXPOSE 8000
CMD python manage.py syncdb --noinput && \
    python manage.py migrate && \
    python manage.py runserver 0.0.0.0:8000
