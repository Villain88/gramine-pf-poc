# gramine-pf-poc

This repository contains a small demonstration of how a flaw in the gramine protected files mechanism can be exploited by an attacker

## Introduction
The repository contains a python enclave template that runs an encrypted script (scripts/crypted.py which is at the same time trusted and protected). The key to the script is stored on the server, which gives it to the enclave using the remote attestation mechanism.
In this example, the server does not check the enclave dimension, but only displays it. In real life, the server checks the measurement and transmits the key only after verification.

The repository also contains two python scripts:
* helloworld.py - non-malicious
* malicious.py - trying to steal secrets meant for other enclaves

and two keys:
* wrap-key (ffeeddccbbaa99887766554434221100) - this key encrypts the helloworld script
* wrap-key2 (00112233445566778899aabbccddeeff) - this key encrypts the malicious script

and build script which:
* encrypts scripts with appropriate keys
* prepares and signs the enclave (you have to prepare the key and place it according to your gramine version)
* builds a server

## Steps to reproduce:
### Step 0
Prepare sign key
### Step 1
Run build script
[![](https://github.com/Villain88/gramine-pf-poc/blob/master/images/1.png)](https://github.com/Villain88/gramine-pf-poc/blob/master/images/1.png "Step 1")

### Step 2
Remember the Enclave measurement
[![](https://github.com/Villain88/gramine-pf-poc/blob/master/images/2.png)](https://github.com/Villain88/gramine-pf-poc/blob/master/images/2.png "Step 2")

### Step 3
Run the server, pass the **first key** as an argument
[![](https://github.com/Villain88/gramine-pf-poc/blob/master/images/3.png)](https://github.com/Villain88/gramine-pf-poc/blob/master/images/3.png "Step 3")

### Step 4
Run the first script in the enclave, make sure the mrenclave and key are correct
[![](https://github.com/Villain88/gramine-pf-poc/blob/master/images/4.png)](https://github.com/Villain88/gramine-pf-poc/blob/master/images/4.png "Step 4")

### Step 5
Stop the server and replace encrypted script helloworld with encrypted script malicious (crypted.py_ -> crypted.py)
[![](https://github.com/Villain88/gramine-pf-poc/blob/master/images/5.png)](https://github.com/Villain88/gramine-pf-poc/blob/master/images/5.png "Step 5")

### Step 6
Run the server, pass the **second key** as an argument and run the **second script** in the enclave.
Make sure the mrenclave and key are correct. Stop the server. The script continues to run.
[![](https://github.com/Villain88/gramine-pf-poc/blob/master/images/6.png)](https://github.com/Villain88/gramine-pf-poc/blob/master/images/6.png "Step 6")

### Step 7
Run the server again, pass the **first key** as an argument.
Malicious script gets the key.
[![](https://github.com/Villain88/gramine-pf-poc/blob/master/images/7.png)](https://github.com/Villain88/gramine-pf-poc/blob/master/images/7.png "Step 7")

## What is the problem and how to solve it:
When preparing an enclave, a manifest (.manifest.sgx) file is created that contains the necessary information about the enclave, including hashes of trusted files.
Manifest hash affects enclave measurement. When trying to access trusted files, their integrity is checked. However, if the file is both trusted and protected, its integrity is not checked, only the validity of the key is checked.
Thus, an attacker can replace a protected file without changing the enclave measurement. A server can only trust an enclave based on its measurements.
And since the measurements does not change, the server gives the key to the one to whom it is not intended. 
One solution is to modify the gramine: add file integrity check based on the hash (of an unencrypted file for example) calculated during the enclave preparation phase

