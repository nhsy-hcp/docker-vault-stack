# add temporary secrets

for i in $(seq 1 3); do
  for j in $(seq 1 3); do
    vault kv put -namespace=bu01 shared/team$i/app$j username=wibble password=secure
    vault kv put -namespace=bu02 shared/team$i/app$j username=wibble password=secure
    vault kv put -namespace=bu03 shared/team$i/app$j username=wibble password=secure
    vault kv put -namespace=bu01 team$i/app$j username=wibble password=secure
  done
done