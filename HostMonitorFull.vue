<template>
  <div style="display:flex; gap:20px;">
    <!-- 左侧：主机管理 + SSH + AWS导入 -->
    <div style="width:40%">
      <h3>主机列表</h3>
      <el-table
        :data="hosts"
        style="width:100%"
        @selection-change="handleSelection"
        ref="hostTable"
      >
        <el-table-column type="selection" width="55"/>
        <el-table-column prop="hostname" label="主机名"/>
        <el-table-column prop="ip" label="IP"/>
      </el-table>

      <h3>SSH命令执行</h3>
      <el-input v-model="sshCommand" placeholder="输入命令" style="width:100%; margin-top:10px"/>
      <el-button type="primary" @click="executeSSH" style="margin-top:5px">执行 SSH</el-button>

      <h3>AWS导入</h3>
      <el-input v-model="awsAccount" placeholder="账号标识" style="width:100%; margin-top:5px"/>
      <el-input v-model="awsAccessKey" placeholder="Access Key" style="width:100%; margin-top:5px"/>
      <el-input v-model="awsSecretKey" placeholder="Secret Key" style="width:100%; margin-top:5px"/>
      <el-button type="success" @click="importAWS" style="margin-top:5px">导入 AWS</el-button>
    </div>

    <!-- 右侧：仪表盘 + Top5进程 + 日志 -->
    <div style="width:60%">
      <h3>CPU趋势图</h3>
      <v-chart :option="cpuOption" style="height:200px"/>

      <h3>内存趋势图</h3>
      <v-chart :option="memOption" style="height:200px"/>

      <h3>网络流量趋势图</h3>
      <v-chart :option="netOption" style="height:200px"/>

      <h3>Top5进程</h3>
      <el-table :data="top5Processes" style="width:100%">
        <el-table-column prop="ip" label="IP"/>
        <el-table-column prop="processes" label="Top5进程">
          <template #default="{ row }">{{ row.processes.join(', ') }}</template>
        </el-table-column>
      </el-table>

      <h3>实时日志</h3>
      <div ref="logContainer" style="height:200px; overflow-y:auto; border:1px solid #ccc; padding:5px">
        <div v-for="log in logs" :key="log">{{ log }}</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, nextTick } from 'vue'
import axios from 'axios'
import VChart from 'vue-echarts'

const hosts = ref([])
const selectedHosts = ref([])
const sshCommand = ref("")
const logs = ref([])
const top5Processes = ref([])
const logContainer = ref(null)

const awsAccount = ref("")
const awsAccessKey = ref("")
const awsSecretKey = ref("")

const cpuHistory = reactive({})
const memHistory = reactive({})
const netHistory = reactive({})

const cpuOption = reactive({ xAxis:{type:'category', data:[]}, yAxis:{type:'value'}, series:[] })
const memOption = reactive({ xAxis:{type:'category', data:[]}, yAxis:{type:'value'}, series:[] })
const netOption = reactive({ xAxis:{type:'category', data:[]}, yAxis:{type:'value'}, series:[] })

const handleSelection = (val) => { selectedHosts.value = val }

const executeSSH = async () => {
  if(!selectedHosts.value.length || !sshCommand.value) return alert("请选择主机并输入命令")
  const ips = selectedHosts.value.map(h=>h.ip)
  await axios.post("http://localhost:8000/ssh/execute",{hosts:ips, command:sshCommand.value})
}

const importAWS = async () => {
  if(!awsAccount.value || !awsAccessKey.value || !awsSecretKey.value) return alert("请填写完整信息")
  const resp = await axios.post("http://localhost:8000/aws/import",{
    account:awsAccount.value,
    access_key:awsAccessKey.value,
    secret_key:awsSecretKey.value
  })
  alert(`导入成功 ${resp.data.imported} 台主机`)
}

onMounted(()=>{
  // 监控 WebSocket
  const ws = new WebSocket("ws://localhost:8000/ws/monitor")
  ws.onmessage = (event)=>{
    const data = JSON.parse(event.data)
    hosts.value = data
    const timestamp = new Date().toLocaleTimeString()
    top5Processes.value = data.map(h=>({ip:h.ip, processes:h.top5||[]}))

    data.forEach(h=>{
      if(!cpuHistory[h.ip]) cpuHistory[h.ip]=[]
      if(!memHistory[h.ip]) memHistory[h.ip]=[]
      if(!netHistory[h.ip]) netHistory[h.ip]={rx:[], tx:[]}

      cpuHistory[h.ip].push(h.cpu||0)
      memHistory[h.ip].push(h.mem||0)
      netHistory[h.ip].rx.push(h.rx||0)
      netHistory[h.ip].tx.push(h.tx||0)

      if(cpuHistory[h.ip].length>20) cpuHistory[h.ip].shift()
      if(memHistory[h.ip].length>20) memHistory[h.ip].shift()
      if(netHistory[h.ip].rx.length>20) netHistory[h.ip].rx.shift()
      if(netHistory[h.ip].tx.length>20) netHistory[h.ip].tx.shift()
    })

    cpuOption.xAxis.data.push(timestamp)
    memOption.xAxis.data.push(timestamp)
    netOption.xAxis.data.push(timestamp)
    if(cpuOption.xAxis.data.length>20) { cpuOption.xAxis.data.shift(); memOption.xAxis.data.shift(); netOption.xAxis.data.shift() }

    cpuOption.series = Object.keys(cpuHistory).map(ip=>({name:ip,type:'line',data:cpuHistory[ip]}))
    memOption.series = Object.keys(memHistory).map(ip=>({name:ip,type:'line',data:memHistory[ip]}))
    netOption.series = Object.keys(netHistory).map(ip=>({name:ip,type:'line',data:netHistory[ip].rx.concat(netHistory[ip].tx)}))
  }

  // 日志 WebSocket
  const wsLog = new WebSocket("ws://localhost:8000/ws/logs")
  wsLog.onmessage = (event)=>{
    const msg = JSON.parse(event.data).log
    logs.value.push(msg)
    nextTick(()=>{ logContainer.value.scrollTop = logContainer.value.scrollHeight })
  }
})
</script>
