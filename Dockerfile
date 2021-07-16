FROM databricksruntime/standard:latest
ARG scalaversion
# update ubuntu
RUN apt-get update
#commented out we might not need all those now
#    && apt-get install -y \
#        build-essential \
#        python3-dev \
#    && apt-get clean
ADD ./target/$scalaversion/*.jar /databricks/jars/
ADD ./lib/*.jar /databricks/jars/
ADD ./lib/jars/*.jar  /databricks/jars/
#
## clean up
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*