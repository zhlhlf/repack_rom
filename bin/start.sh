#!/bin/bash

work_dir=$(pwd)
tools_dir=${work_dir}/bin/$(uname)/$(uname -m)
export PATH=$PATH:$(pwd)/bin/pys:$(pwd)/bin/$(uname)/$(uname -m)/
chmod 777 * -R

# 导入环境变量
. ./config

# Import functions
. ./bin/functions.sh

blue "正在清理文件" "Cleaning up.."
rm -rf app tmp baserom portrom out

green "文件清理完毕" "Files cleaned up."

mkdir -p baserom/images portrom/images out/images out/firmware-update

# 底包和移植包为外部参数传入
baseromUrl="$1"
portromUrl="$2"

baserom=base.rom
portrom=port.rom

# 下载底包
download_rom "${baserom}" "${baseromUrl}"
# 下载移植包
download_rom "${portrom}" "${portromUrl}"

# 提取底包中所有镜像
extract_rom ${baserom} baserom/images/
# 提取底包中所有镜像
extract_rom ${portrom} portrom/

#判断是否是移植rom 根据移植包有没有下载成功和解压成功
if [ -f portrom/system.img ]; then
    is_yz=true
else
    is_yz=false
fi

#
if [ -f ./zhlhlf0.sh ]; then
    green "存在自定义编辑 开始执行"
    . ./zhlhlf0.sh
else
    yellow "自定义编辑脚本不存在"
fi

#分解*boot*文件
for im in $(find baserom/images/*boot*); do
    extract_img $im portrom/images
    rm -rf $im
done

# 匹配super_list列表
super_list=""
for i in $(find baserom/images/*.img | sed s/.img//g); do
    filename=$(basename $i)
    for j in $possible_super_list; do
        if [[ $filename = $j ]]; then
            super_list+="$filename "
        fi
    done
done

yellow "super_list: $super_list"

if [ $is_yz = true ]; then
    #分解底包指定文件
    green "开始分解底包中指定镜像"
    list="system product system_ext my_product my_manifest odm"
    for image in $list; do
        if [ -f baserom/images/${image}.img ]; then
            extract_img baserom/images/${image}.img baserom/images
        fi
    done

    # Move those to portrom folder. We need to pack those imgs into final port rom
    green "开始分解要替换为底包于目标包的镜像"
    list="vendor odm my_company my_preload"
    for image in $list; do
        if [ -f baserom/images/${image}.img ]; then
            extract_img baserom/images/${image}.img portrom/images
        else
            yellow "$image 不存在"
        fi
    done

    # 提取目标rom指定镜像并分解
    green "开始分解目标包剩余逻辑分区镜像"
    list=${super_list}
    list+=" reserve"
    for image in ${list}; do
        rm -rf baserom/images/${image}.img
        if [ -d portrom/images/${image} ]; then
            continue
        fi
        if [ -f portrom/${image}.img ]; then
            extract_img portrom/${image}.img portrom/images
            rm -rf portrom/${image}.img
        fi
    done

    get_rom_msg baserom/images portrom/images

    #全局替换device_code
    change_device_buildProp portrom/images

else
    for im in $super_list; do
        extract_img baserom/images/$im.img portrom/images
        rm -rf baserom/images/$im.img
    done

    # wait for env_yes 管道输入
    read message < /mnt/repack_rom/env_yes

    get_rom_msg portrom/images

fi

# 通常是精简脚本或者移植脚本 在打解目录执行
if [ -f ./zhlhlf1.sh ]; then
    green "存在自定义编辑 开始执行"
    cd portrom/images
    . ../../zhlhlf1.sh | tee -a ../../out/edit.txt
    cd ../../
else
    yellow "自定义编辑脚本不存在"
fi

# if extract img
if [ $extract_img = true ]; then

    if grep -q "ro.build.ab_update=true" portrom/images/vendor/build.prop; then
        update_type=AB
    else
        update_type=A
    fi

    # build.prop 修改 时间
    change_buildTime_buildProp portrom/images

    #去除系统签名校验
    if [ $closeSystemApkSingnCheck = true ]; then
        blue "去系统apk签名验证.."
        #处理 framework.jar 去系统apk签名验证
        # patch_methods="getMinimumSignatureSchemeVersionForTargetSdk "
        # paths="android/util/apk "
        # patch1_jar portrom/images/system/system/framework/framework.jar "$paths" "$patch_methods"

        #处理 services.jar 去系统apk签名验证
        patch_methods="--assertMinSignatureSchemeIsValid "
        paths="com/android/server/pm/ "
        patch1_jar portrom/images/system/system/framework/services.jar "$paths" "$patch_methods"

        #处理 services.jar 去系统apk签名验证
        patch_methods="getMinimumSignatureSchemeVersionForTargetSdk"
        paths="com/android/server/pm/ "
        patch2_jar portrom/images/system/system/framework/services.jar "$paths" "$patch_methods"
    fi

    #添加erofs文件系统fstab
    if [ $pack_type = "erofs" ]; then
        edit_fstab_ext_to_erofs portrom/images
    fi

    if [ $disable_avb_verify = true ]; then
        disable_avb_verify portrom/images
    fi

    if [ $remove_data_encrypt = true ]; then
        remove_data_encrypt portrom/images
    fi

    if [ "$base_rom_density" ]; then
        edit_rom_density portrom/images $base_rom_density
    fi

    # 打包各镜像img
    for i in $(ls portrom/images --hide config); do
        repack_img "portrom/images/$i" $pack_type
    done

    rm -rf portrom/images/*.img
    mv -f portrom/images/out/*.img portrom/images/

    green "edit vbmeta.img 关闭avb校验"
    patch-vbmeta.py baserom/images/vbmeta.img

fi

# 打包super
if [ $make_super = true ]; then

    data=$(grep "$base_product_device $update_type" bin/superMsgList.txt)
    if [ ! "$data" ]; then
        yellow "未找到 $base_product_device $update_type 机型打包super参数 将使用默认参数"
        data=$(sed -n 1p bin/superMsgList.txt)
    fi
    super_size=$(echo $data | awk '{print $3}')
    super_type=$(echo $data | awk '{print $4}')

    make_super "portrom/images" "$super_list" "$super_type" "$super_slot"

    blue "正在压缩 super.img"
    zstd portrom/images/super.img -o out/images/super.zst

    for i in $super_list super; do
        rm -rf portrom/images/$i*
    done
fi

blue "正在生成刷机zip"

mv portrom/images/*.img out/images

for i in dtbo *vbmeta*; do
    mv -f baserom/images/$i.img out/images/
done

#剩余的作为底包
mv baserom/images/*.* out/firmware-update

rm -rf portrom

cd out
echo "by zhlhlf" >>edit.txt

# 在打包zip之前执行
if [ -f ../zhlhlf2.sh ]; then
    green "存在自定义编辑 开始执行"
    . ../zhlhlf2.sh
else
    yellow "自定义编辑脚本不存在"
fi

green "要打包为zip的文件目录树"
green "---------------------"
du -h $(find -type f)
green "---------------------"

#多线程压缩 加快速度
7z a -tzip -mmt=on out.zip * >>/dev/null

time=$(date +"%Y-%m-%d")
hash=$(md5sum out.zip | head -c 5)

base_rom_version=$(echo $base_rom_version | sed s/[^0-9.A-Z]//g)

if [ $is_yz = true ]; then
    mv out.zip ${base_product_device=$(echo $base_product_device | sed s/[^0-9.A-Z]//g)}_${update_type}_${port_rom_version}_from_${port_product_device}_${pack_type}_${time}_${hash}.zip
else
    mv out.zip ${base_product_device}_${update_type}_${base_rom_version}_${pack_type}_${time}_${hash}.zip
fi

cd ..
green "输出包路径："
green $(ls out/*.zip)
