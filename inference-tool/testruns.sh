shopscanner=/home/michael/Documents/PHILAE/scanette/traces/1026-steps-preprocessed.json
rm dotfiles/*; java -Dscalapy.python.library=python3.9 -Dscalapy.python.programname=/home/michael/Documents/efsm-inference/inference-tool/deapGP/bin/python3.9 -jar target/scala-2.12/inference-tool-assembly-0.1.0-SNAPSHOT.jar -o 3 -u 20 -p gp -s naive_eq_bonus -h ws -d dotfiles -t 10 $shopscanner $shopscanner
liftdoors=experimental-data/liftDoors30/liftDoors30-1/liftDoors30-obfuscated-time-train.json 
rm dotfiles2/*; java -Dscalapy.python.library=python3.9 -Dscalapy.python.programname=/home/michael/Documents/efsm-inference/inference-tool/deapGP/bin/python3.9 -jar target/scala-2.12/inference-tool-assembly-0.1.0-SNAPSHOT.jar -o 3 -u 20 -p gp -s naive_eq_bonus -h ws -d dotfiles2 -t 15 $liftdoors $liftdoors 
spaceinvaders=experimental-data/spaceInvaders30/spaceInvaders30-1/spaceInvaders30-obfuscated-x-train.json 
rm dotfiles3/*; java -Dscalapy.python.library=python3.9 -Dscalapy.python.programname=/home/michael/Documents/efsm-inference/inference-tool/deapGP/bin/python3.9 -jar target/scala-2.12/inference-tool-assembly-0.1.0-SNAPSHOT.jar -o 3 -u 20 -p gp -s naive_eq_bonus -h ws -d dotfiles3 -t 20 $spaceinvaders $spaceinvaders

