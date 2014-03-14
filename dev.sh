#!/bin/bash

# 几个有用的变量
__file__=$(readlink -f "$0")
__name__=$(basename "$__file__")
__dir__=$(dirname "$__file__")

function usage()
{
    local cmd=$(basename "$0")
    cat << EOF
NAME:
    $cmd - Command

USAGE:
    $cmd [options] [arguments]

OPTIONS:
    -h          this help information
EOF
}

function linkfile()
{
    ln -sfv "$@"
}

##
## 主流程
##

## 参数解析
opt_optarg=""
while getopts "i:h" opt; do
    case "$opt" in
    "i")
        opt_optarg="$OPTARG"
        ;;
    "h")
        usage "$0"
        exit 0
        ;;
    "?")
        # optstring的第一个字符不为':'时，遇到非法选项时的处理
        usage "$0"
        exit 1
        ;;
    esac
done
shift $((OPTIND - 1))

## 流程开始
# 基础目录
DESTDIR=$(readlink -f "videm-dev")
# _videm
VIDEM_DIR=${DESTDIR}/_videm
# _videm/core
VIDEM_PYDIR=${VIDEM_DIR}/core
# autoload/vpymod, 公共的 py 库
VPYMOD_DIR=${DESTDIR}/autoload/vpymod
# autoload/videm/plugin, videm 的插件目录
VIDEM_PLUGIN_DIR="$DESTDIR/autoload/videm/plugin"

# skel_dir
rm -rf "$DESTDIR"
mkdir -p "${DESTDIR}"
mkdir -p "${DESTDIR}"/autoload
mkdir -p "${DESTDIR}"/doc
mkdir -p "${DESTDIR}"/plugin
mkdir -p "${DESTDIR}"/syntax
mkdir -p "${VIDEM_DIR}"
mkdir -p "${VIDEM_DIR}"/bin
mkdir -p "${VIDEM_DIR}"/config
mkdir -p "${VIDEM_DIR}"/lib
mkdir -p "${VIDEM_PYDIR}"
mkdir -p "${VPYMOD_DIR}"
mkdir -p "$VIDEM_PLUGIN_DIR"

linkfile "$__dir__"/common/*.py "$VPYMOD_DIR"
linkfile "$__dir__"/lib/*.py "$VPYMOD_DIR"

# cscope plugin
linkfile "$__dir__/plugin/cscope"/*.vim "$VIDEM_PLUGIN_DIR"

# gtags plugin
linkfile "$__dir__/plugin/gtags"/*.vim "$VIDEM_PLUGIN_DIR"

# omnicpp plugin
files=(
    CppParser.py
    CppTokenizer.py
    CxxHWParser.py
    CxxParser.py
    FileReader.py
    OmniCpp.py
    CtagsDatabase/FileEntry.py
    CtagsDatabase/ITagsStorage.py
    CtagsDatabase/TagEntry.py
    CtagsDatabase/TagsStorageSQLite.py
    CtagsDatabase/VimTagsManager.py
    __init__.py
)
mkdir -p "$VPYMOD_DIR/omnicpp"
for file in "${files[@]}"; do
    linkfile "$__dir__/plugin/omnicpp/$file" "$VPYMOD_DIR/omnicpp"
done

files=(
    complete.vim
    includes.vim
    resolvers.vim
    scopes.vim
    settings.vim
    tokenizer.vim
    utils.vim
)
mkdir -p "$DESTDIR/autoload/omnicpp"
for file in "${files[@]}"; do
    linkfile "$__dir__/plugin/omnicpp/$file" "$DESTDIR/autoload/omnicpp"
done
linkfile "$__dir__/plugin/omnicpp/omnicpp.vim" "$VIDEM_PLUGIN_DIR"
linkfile "$__dir__/plugin/omnicpp/CtagsDatabase/vltagmgr.vim" "$DESTDIR/autoload"

# omnicxx plugin
mkdir -p "$VPYMOD_DIR/omnicxx"
linkfile "$__dir__/plugin/omnicxx"/omnicxx.vim "$VIDEM_PLUGIN_DIR"
mkdir -p "$DESTDIR/autoload/omnicxx"
linkfile "$__dir__/plugin/omnicxx"/complete.vim "$DESTDIR/autoload/omnicxx"

mkdir -p "$VPYMOD_DIR/omnicxx"
linkfile "$__dir__/plugin/omnicxx"/omnicxx/*.py "$VPYMOD_DIR/omnicxx"

mkdir -p "$VPYMOD_DIR/omnicxx/TagsStorage"
linkfile "$__dir__/plugin/omnicxx"/omnicxx/TagsStorage/*.py "$VPYMOD_DIR/omnicxx/TagsStorage"

# pyclewn plugin
linkfile "$__dir__/plugin/pyclewn/pyclewn/bin"/* "$VIDEM_DIR/bin"
linkfile "$__dir__/plugin/pyclewn/pyclewn/pyclewn" "$VIDEM_DIR"
linkfile "$__dir__/plugin/pyclewn"/pyclewn/vim/autoload/* "$DESTDIR/autoload"
linkfile "$__dir__/plugin/pyclewn"/pyclewn/vim/doc/* "$DESTDIR/doc"
linkfile "$__dir__/plugin/pyclewn"/pyclewn/vim/plugin/* "$DESTDIR/plugin"
linkfile "$__dir__/plugin/pyclewn"/pyclewn/vim/syntax/* "$DESTDIR/syntax"
linkfile "$__dir__/plugin/pyclewn"/pyclewn.vim "$VIDEM_PLUGIN_DIR"
mkdir -p "$VIDEM_DIR/doc"
mv -v "$DESTDIR/doc/vpyclewn.txt" "$VIDEM_DIR/doc"

# vimccc plugin
linkfile "$__dir__/plugin/vimccc"/VIMClangCC.py "$VIDEM_PYDIR"
mkdir -p "$DESTDIR/autoload/vimccc"
linkfile "$__dir__/plugin/vimccc"/core.vim "$DESTDIR/autoload/vimccc"
linkfile "$__dir__/plugin/vimccc"/vimccc_plugin.vim "$DESTDIR/plugin"
linkfile "$__dir__/plugin/vimccc"/vimccc.vim "$VIDEM_PLUGIN_DIR"
linkfile "$__dir__/plugin/vimccc"/clang "$VIDEM_PYDIR"

# vim folder
linkfile "$__dir__"/vim/autoload/vpymod/*.vim "$VPYMOD_DIR"
linkfile "$__dir__"/vim/autoload/*.vim "$DESTDIR/autoload"

# wsp folder
files=(
    BuildConfig.py
    BuilderGnuMake.py
    BuilderManager.py
    Builder.py
    BuildMatrix.py
    BuildSettings.py
    BuildSystem.py
    Compiler.py
    EnvVarSettings.py
    GetTemplateDict.py
    Project.py
    ProjectSettings.py
    TagsSettings.py
    VLProject.py
    VLProjectSettings.py
    VLWorkspace.py
    VLWorkspaceSettings.py
    XmlUtils.py
    VidemSession.py
    Macros.py
)

for file in "${files[@]}"; do
    linkfile "$__dir__/wsp/$file" "$VIDEM_PYDIR"
done
mkdir -p "${DESTDIR}/autoload/videm"
linkfile "$__dir__/wsp/videm.vim" "${DESTDIR}/plugin"
linkfile "$__dir__/wsp/"{settings.vim,wsp.vim,wsp.py} "${DESTDIR}/autoload/videm"
linkfile "$__dir__/wsp/syntax"/* "$DESTDIR/syntax"
mkdir -p "${VIDEM_DIR}/config"
linkfile "$__dir__/wsp/BuildSettings.jcnf" "${VIDEM_DIR}/config"
linkfile "$__dir__/wsp/templates" "$VIDEM_DIR"
linkfile "$__dir__/wsp/bitmaps" "$VIDEM_DIR"
linkfile "$__dir__/wsp/tools"/* "$VIDEM_DIR"

linkfile "$__dir__"/videm.txt "$DESTDIR/doc"

if [ ! -d ~/.vim/bundle ]; then
cat << EOF
~/.vim/bundle folder not found
please run "cd tools/videm-tools && make && make install" after install pathogen
EOF
    exit 0
fi

ln -sv "$DESTDIR" ~/.vim/bundle

# build videm-tools
cd tools/videm-tools && make && make install
cd - >/dev/null

echo "========================================"
echo "Done."
echo "Go to develop :)"

# vi:set et sts=4 sw=4 ts=8:
