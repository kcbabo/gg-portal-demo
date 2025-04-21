# LTS release of Node
FROM node:bookworm-slim
# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available (npm@5+)
COPY package*.json ./

RUN npm install -g json-server@0.17.4
# If you are building your code for production
# RUN npm ci --only=production

# Bundle app source
#COPY . .
COPY db.json db.json
COPY public/swagger.json public/swagger.json

EXPOSE 5000

CMD [ "json-server", "--host", "::", "--port", "5000", "db.json" ]
