FROM python:2.7-stretch

ENV APP_HOME /usr/src/app/

COPY notejam /usr/src/app

WORKDIR $APP_HOME

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8000

CMD ["sh", "-c", "python3 manage.py migrate && python3 manage.py runserver 0.0.0.0:8000"]
