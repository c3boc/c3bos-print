FROM ruby:2.4.2-slim
RUN apt-get update
RUN apt-get install -y gcc make imagemagick libmagickwand-dev libcurl3-dev libmagickcore-dev libmagickwand-dev

RUN ln -s /usr/lib/x86_64-linux-gnu/ImageMagick-6.8.9/bin-Q16/Magick-config /usr/bin/Magick-config

WORKDIR /app
COPY . .

RUN bundle install

ENTRYPOINT ["bundle", "exec"]
CMD ["ruby", "./client.rb"]
