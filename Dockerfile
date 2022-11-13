# was originally targetting '16-arm64' for the image + lambda runtime but github
# actions does not have a free arm runner to to do arm builds. (revisit)
ARG node_image_tag=16

###############################################################################
# Build
###############################################################################

# The build step does an 'esbuild' of our typescript based lambda
# function, producing a single index.js file for copying into our
# final image
FROM public.ecr.aws/lambda/nodejs:${node_image_tag} as builder
WORKDIR /usr/app
COPY package.json index.ts  ./
RUN npm install
RUN npm run build


###############################################################################
# Bake
###############################################################################

FROM public.ecr.aws/lambda/nodejs:${node_image_tag}

ARG migrate_version=v4.15.2
ARG migrate_platform=linux
# options: arm64 | amd64
# was originally targetting arm64 for the image + lambda runtime but github
# actions does not have a free arm runner to to do arm builds. (revisit)
ARG migrate_arch=amd64

# Install [migrate](https://github.com/golang-migrate/migrate)
# We execute the cli version of migrate from our lambda function to trigger
# the database migrations.
RUN mkdir -p /opt/migrate
WORKDIR /opt/migrate
RUN yum install tar gzip wget -y
RUN wget https://github.com/golang-migrate/migrate/releases/download/${migrate_version}/migrate.${migrate_platform}-${migrate_arch}.tar.gz
RUN tar -xvf migrate.${migrate_platform}-${migrate_arch}.tar.gz
RUN ln -s /opt/migrate/migrate /usr/local/bin/migrate
RUN yum remove tar gzip wget -y
RUN rm migrate.${migrate_platform}-${migrate_arch}.tar.gz

# Copy in our built nodejs lambda function
WORKDIR ${LAMBDA_TASK_ROOT}
COPY --from=builder /usr/app/dist/* ./

CMD ["index.handler"]
