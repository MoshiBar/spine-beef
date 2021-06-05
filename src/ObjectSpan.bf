using System;

namespace Spine
{
	struct ObjectSpan<T> : IRawAllocator where T : delete
	{
		const int Stride = typeof(T).InstanceStride;

		public uint8* data;
		int index = 0;
		int* indexref;
		public int Count;

		public this(int count){
			Count = count;
			indexref = &index;
			data = new uint8[count * typeof(T).InstanceStride]* (?);
#if BF_ENABLE_REALTIME_LEAK_CHECK
			GC.AddRootCallback(new () => GCMarkMembers());
#endif
		}

		public T this[int idx] => (T)Internal.UnsafeCastToObject(data + idx * Stride);

		public void* Alloc(int size, int align)
		{
			return &data[indexref[0]++ * Stride];
		}

		public void Free(void* ptr){}

		public void Dispose(){
			for(int i = 0; i < Count; i++) delete:null this[i];
			delete data;
		}
#if BF_ENABLE_REALTIME_LEAK_CHECK
		protected override void GCMarkMembers(){
			for(int i < Count) {
				//GC.Mark(this[i]);
				this[i].[Friend]GCMarkMembers();
			}
		}
#endif

		public void CopyTo(Span<T> array){
			int count = Math.Min(Count, array.Length);
			for(int i < count) array[i] = this[i];
		}
	}
}