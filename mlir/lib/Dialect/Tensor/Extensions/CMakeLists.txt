set(LLVM_OPTIONAL_SOURCES
  AllExtensions.cpp
  ShardingExtensions.cpp
  )

add_mlir_extension_library(MLIRTensorShardingExtensions
  ShardingExtensions.cpp

  ADDITIONAL_HEADER_DIRS
  ${MLIR_MAIN_INCLUDE_DIR}/mlir/Dialect/Tensor/Extensions

  LINK_LIBS PUBLIC
  MLIRTensorDialect
  MLIRIR
  MLIRShardingInterface
  )

add_mlir_extension_library(MLIRTensorAllExtensions
  AllExtensions.cpp

  ADDITIONAL_HEADER_DIRS
  ${MLIR_MAIN_INCLUDE_DIR}/mlir/Dialect/Tensor/Extensions

  LINK_LIBS PUBLIC
  MLIRTensorShardingExtensions
  )