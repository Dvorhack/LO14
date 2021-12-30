Projet LO14 à l'UTT

Pour tester le projet en local:

docker build -t lo14 .
docker run -p 2222:22 lo14 

On peut maintenant communiquer avec le serveur ssh sur le port 2222
Par défault, les credentials sont : test:test
