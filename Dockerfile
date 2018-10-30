FROM ruby:2.3
RUN useradd -m user
RUN mkdir /home/user/app
WORKDIR /home/user/app
COPY Gemfile* ./
RUN chown user:user Gemfile
USER user
RUN bundle install
COPY . .
USER root
RUN chown user:user *
USER user
CMD ["rackup","-o","0.0.0.0","-p","4567"]
#CMD ["/usr/local/bin/ruby","main.rb","-o","0.0.0.0"]
