# 用户输入基本信息
read -p "SSL HTTP proxy must need a domain, (e.g., proxy.yourdomain.com),
input a domain:" domain
if [ "$domain" = "" ]; then
    echo "No domain input, exit!"
    exit 1
fi

read -p "input the port for ssl http proxy:, (default:5678):" port
if [ "$port" = "" ]; then
    port=5678
fi

# 安装软件
apt-get update
apt-get install -y  git apt-transport-https

# 生成ssl证书
git clone https://github.com/letsencrypt/letsencrypt /opt/letsencrypt
/opt/letsencrypt/letsencrypt-auto certonly --standalone -d $domain

# 安装erlang虚拟机
declare -a sources=("deb https://packages.erlang-solutions.com/ubuntu trusty contrib" "deb https://packages.erlang-solutions.com/ubuntu saucy contrib" "deb https://packages.erlang-solutions.com/ubuntu precise contrib")
for source in "${sources[@]}"
do
    if grep -q "$source" /etc/apt/sources.list;then
        echo $source
    else
        echo $source | tee --append  /etc/apt/sources.list
fi
done

wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc
apt-key add erlang_solutions.asc
apt-get update
apt-get install -y esl-erlang

# 部署 ssl http 代理
wget https://sakura.njunova.com/file/https_proxy.tar.gz
tar -xzvf https_proxy.tar.gz

echo '#!/bin/sh
cd /root/https_proxy
erl -eval "server:start(100,1234,'$port',\"/etc/letsencrypt/live/'$domain'\")." -detached >/dev/null 2>&1'> https_proxy/start.sh
cd https_proxy
bash start.sh

# 检测是否启动成功
test_ps=`ps -ef|grep beam`
if [[ $test_ps == *"erlang"* ]]; then
    echo "SSL HTTP Proxy Running now!"
else
    echo "SSL HTTP Proxy Launch Failed, Exit!"
    exit 1    
fi

# 设置开机自动启动
https_proxy_dir=$(pwd)
script=$https_proxy_dir/start.sh
https_startup_crontab='@reboot '$USER' '$script''
if grep -q "$https_startup_crontab" /etc/crontab;then
    echo "ssl http proxy has been ready for startup on boot now!"
else
    echo '@reboot '$USER' '$script'' | sudo tee --append /etc/crontab
    echo "ssl http proxy can startup on boot now!"
fi

# 输出配置
echo 'All done! User list(username:password):'
cat auth
echo ""

