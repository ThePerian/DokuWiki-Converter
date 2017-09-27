# DokuWiki-Converter
In addition to Unoconv for document converting it requires following perl modules to work:
- HTML::WikiConverter;
- RPC::XML::Client;
- JSON;
- Time::localtime;
- File::Find;
- File::stat;
- Cwd;
- utf8;
- Encode.

## Windows setup
Install strawberry-perl-5.24.0.1-(32|64)bit.msi, it comes with cpan for command line, adds perl to %PATH% and associates \*.pl files.
Unzip required perl modules into the same folder as DokuWiki Converter. Open command line and install required perl modules:
```
cd ./HTML-WikiConverter-0.68
cpan .
cd ../HTML-WikiConverter-DokuWiki-0.54
cpan .
cd ../Scalar-List-Utils-1.46
cpan .
cd ../RPC-XML-0.80
cpan .
cd ../JSON-2.90
cpan .
cd ../
mv config.json.example config.json
perl convert.pl
notepad test.html.txt
```

## Linux (Ubuntu) setup
Copy following text in .sh file, assuming you have required perl modules in the same folder:
```
# install HTML::WikiConverter
tar xzf HTML-WikiConverter-0.68.tar.gz
cd HTML-WikiConverter-0.68
sudo cpan .
# install dialect HTML::WikiConverter::DokuWiki
tar xzf ../HTML-WikiConverter-DokuWiki-0.54.tar.gz
cd ../HTML-WikiConverter-DokuWiki-0.54
sudo cpan .
# install module to use DokuWiki API
tar xzf ../Scalar-List-Utils-1.46.tar.gz
cd ../Scalar-List-Utils-1.46
sudo cpan .
tar xzf ../RPC-XML-0.80.tar.gz
cd ../RPC-XML-0.80
sudo cpan .
# install module to use JSON
tar xzf ../JSON-2.90.tar.gz
cd ../JSON-2.90
sudo cpan .
# install unoconv
sudo apt-get install unoconv
# fill login and password in config.json
mv config.json.example config.json
# test module
cd ../
perl convert.pl
cat test.html.txt
```

## How to use
Before using module it is necessary to create a copy of `config.json.example` file named `config.json` and fill it with following information:
- endpoint - request url that module will use to access DokuWiki API;
- login and password - used to access your DokuWiki, make sure that you have rw rights;
- wikiuri - your DokuWiki url to create working links in converted text;
- python - path to python.exe, not necessary on Linux;
- datafolder - path to the folder containing resulting DokuWiki pages, used to calculate length of file names;
- other lines should be left untouched.
`version.json` is used to store versions of converted files.

After creating config file simply put `convert.pl`, `config.json` and `version.json` in the same folder with documents that you wish to convert and run
```
perl convert.pl
```

# Why different convert.pl's?
`convert_1req*` is used to make one upload request to DokuWiki API and if it fails, modules stops. Module measures length of resulting file name and trims one time to create acceptable file name. As you can guess there are two versions of module: for Linux and Windows systems.
`convert_nreq*` does not measure file name and instead if upload to DokuWiki fails, it trims filename by one symbol and repeats request until it succeeds.
