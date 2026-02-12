// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 1;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String,
      amount: fields[1] as double,
      categoryId: fields[2] as int,
      date: fields[3] as DateTime,
      description: fields[4] as String,
      receiptData: (fields[5] as Map?)?.cast<String, dynamic>(),
      isPlanned: fields[6] as bool,
      plannedDate: fields[7] as DateTime?,
      isRecurring: fields[8] as bool,
      recurrenceRule: fields[9] as String?,
      nextRecurrenceDate: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.categoryId)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.receiptData)
      ..writeByte(6)
      ..write(obj.isPlanned)
      ..writeByte(7)
      ..write(obj.plannedDate)
      ..writeByte(8)
      ..write(obj.isRecurring)
      ..writeByte(9)
      ..write(obj.recurrenceRule)
      ..writeByte(10)
      ..write(obj.nextRecurrenceDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
