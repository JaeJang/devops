# Specify a base image
FROM node:alpine

WORKDIR /home/app

# Install some dependencies
COPY package.json ./
RUN npm install
# By doing this, npm install will be executed when only there is 
# any changes on package.json
COPY ./ ./




# Default commnad
CMD ["npm", "start"]