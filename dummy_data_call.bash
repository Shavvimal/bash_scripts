
# Collect test dummy data
curl --location --request GET 'https://jsonplaceholder.typicode.com/todos/1'
wget https://jsonplaceholder.typicode.com/todos/1

# launch a Bash terminal / sh within a container.
docker exec -it ecs-quadra-security-15-quadra-security-f8bcdeb2e8f2c0ee8c01 /bin/bash
docker exec -it ecs-quadra-security-15-quadra-security-f8bcdeb2e8f2c0ee8c01 /bin/sh
